# encoding: utf-8
require 'backup/cloud_io/base'
require 'fog'
require 'digest/md5'
require 'base64'
require 'stringio'

module Backup
  module CloudIO
    class S3 < Base
      class Error < Backup::Error; end

      MAX_FILE_SIZE       = 1024**3 * 5   # 5 GiB
      MAX_MULTIPART_SIZE  = 1024**4 * 5   # 5 TiB

      attr_reader :access_key_id, :secret_access_key, :use_iam_profile,
                  :region, :bucket, :chunk_size, :encryption, :storage_class,
                  :fog_options

      def initialize(options = {})
        super

        @access_key_id      = options[:access_key_id]
        @secret_access_key  = options[:secret_access_key]
        @use_iam_profile    = options[:use_iam_profile]
        @region             = options[:region]
        @bucket             = options[:bucket]
        @chunk_size         = options[:chunk_size]
        @encryption         = options[:encryption]
        @storage_class      = options[:storage_class]
        @fog_options        = options[:fog_options]
      end

      # The Syncer may call this method in multiple threads.
      # However, #objects is always called prior to multithreading.
      def upload(src, dest)
        file_size = File.size(src)
        chunk_bytes = chunk_size * 1024**2
        if chunk_bytes > 0 && file_size > chunk_bytes
          raise FileSizeError, <<-EOS if file_size > MAX_MULTIPART_SIZE
            File Too Large
            File: #{ src }
            Size: #{ file_size }
            Max Multipart Upload Size is #{ MAX_MULTIPART_SIZE } (5 TiB)
          EOS

          chunk_bytes = adjusted_chunk_bytes(chunk_bytes, file_size)
          upload_id = initiate_multipart(dest)
          parts = upload_parts(src, dest, upload_id, chunk_bytes, file_size)
          complete_multipart(dest, upload_id, parts)
        else
          raise FileSizeError, <<-EOS if file_size > MAX_FILE_SIZE
            File Too Large
            File: #{ src }
            Size: #{ file_size }
            Max File Size is #{ MAX_FILE_SIZE } (5 GiB)
          EOS

          put_object(src, dest)
        end
      end

      # Returns all objects in the bucket with the given prefix.
      #
      # - #get_bucket returns a max of 1000 objects per request.
      # - Returns objects in alphabetical order.
      # - If marker is given, only objects after the marker are in the response.
      def objects(prefix)
        objects = []
        resp = nil
        prefix = prefix.chomp('/')
        opts = { 'prefix' => prefix + '/' }

        while resp.nil? || resp.body['IsTruncated']
          opts.merge!('marker' => objects.last.key) unless objects.empty?
          with_retries("GET '#{ bucket }/#{ prefix }/*'") do
            resp = connection.get_bucket(bucket, opts)
          end
          resp.body['Contents'].each do |obj_data|
            objects << Object.new(self, obj_data)
          end
        end

        objects
      end

      # Used by Object to fetch metadata if needed.
      def head_object(object)
        resp = nil
        with_retries("HEAD '#{ bucket }/#{ object.key }'") do
          resp = connection.head_object(bucket, object.key)
        end
        resp
      end

      # Delete object(s) from the bucket.
      #
      # - Called by the Storage (with objects) and the Syncer (with keys)
      # - Deletes 1000 objects per request.
      # - Missing objects will be ignored.
      def delete(objects_or_keys)
        keys = Array(objects_or_keys).dup
        keys.map!(&:key) if keys.first.is_a?(Object)

        opts = { :quiet => true } # only report Errors in DeleteResult
        until keys.empty?
          _keys = keys.slice!(0, 1000)
          with_retries('DELETE Multiple Objects') do
            resp = connection.delete_multiple_objects(bucket, _keys, opts.dup)
            unless resp.body['DeleteResult'].empty?
              errors = resp.body['DeleteResult'].map do |result|
                error = result['Error']
                "Failed to delete: #{ error['Key'] }\n" +
                "Reason: #{ error['Code'] }: #{ error['Message'] }"
              end.join("\n")
              raise Error, "The server returned the following:\n#{ errors }"
            end
          end
        end
      end

      private

      def connection
        @connection ||= begin
          opts = { :provider => 'AWS', :region => region }
          if use_iam_profile
            opts.merge!(:use_iam_profile => true)
          else
            opts.merge!(
              :aws_access_key_id      => access_key_id,
              :aws_secret_access_key  => secret_access_key
            )
          end
          opts.merge!(fog_options || {})
          conn = Fog::Storage.new(opts)
          conn.sync_clock
          conn
        end
      end

      def put_object(src, dest)
        md5 = Base64.encode64(Digest::MD5.file(src).digest).chomp
        options = headers.merge('Content-MD5' => md5)
        with_retries("PUT '#{ bucket }/#{ dest }'") do
          File.open(src, 'r') do |file|
            connection.put_object(bucket, dest, file, options)
          end
        end
      end

      def initiate_multipart(dest)
        Logger.info "\s\sInitiate Multipart '#{ bucket }/#{ dest }'"

        resp = nil
        with_retries("POST '#{ bucket }/#{ dest }' (Initiate)") do
          resp = connection.initiate_multipart_upload(bucket, dest, headers)
        end
        resp.body['UploadId']
      end

      # Each part's MD5 is sent to verify the transfer.
      # AWS will concatenate all parts into a single object
      # once the multipart upload is completed.
      def upload_parts(src, dest, upload_id, chunk_bytes, file_size)
        total_parts = (file_size / chunk_bytes.to_f).ceil
        progress = (0.1..0.9).step(0.1).map {|n| (total_parts * n).floor }
        Logger.info "\s\sUploading #{ total_parts } Parts..."

        parts = []
        File.open(src, 'r') do |file|
          part_number = 0
          while data = file.read(chunk_bytes)
            part_number += 1
            md5 = Base64.encode64(Digest::MD5.digest(data)).chomp

            with_retries("PUT '#{ bucket }/#{ dest }' Part ##{ part_number }") do
              resp = connection.upload_part(
                bucket, dest, upload_id, part_number, StringIO.new(data),
                { 'Content-MD5' => md5 }
              )
              parts << resp.headers['ETag']
            end

            if i = progress.rindex(part_number)
              Logger.info "\s\s...#{ i + 1 }0% Complete..."
            end
          end
        end
        parts
      end

      def complete_multipart(dest, upload_id, parts)
        Logger.info "\s\sComplete Multipart '#{ bucket }/#{ dest }'"

        with_retries("POST '#{ bucket }/#{ dest }' (Complete)") do
          resp = connection.complete_multipart_upload(bucket, dest, upload_id, parts)
          raise Error, <<-EOS if resp.body['Code']
            The server returned the following error:
            #{ resp.body['Code'] }: #{ resp.body['Message'] }
          EOS
        end
      end

      def headers
        headers = {}

        enc = encryption.to_s.upcase
        headers.merge!(
          { 'x-amz-server-side-encryption' => enc}
        ) unless enc.empty?

        sc = storage_class.to_s.upcase
        headers.merge!(
          { 'x-amz-storage-class' => sc }
        ) unless sc.empty? || sc == 'STANDARD'

        headers
      end

      def adjusted_chunk_bytes(chunk_bytes, file_size)
        return chunk_bytes if file_size / chunk_bytes.to_f <= 10_000

        mb = orig_mb = chunk_bytes / 1024**2
        mb += 1 until file_size / (1024**2 * mb).to_f <= 10_000
        Logger.warn Error.new(<<-EOS)
          Chunk Size Adjusted
          Your original #chunk_size of #{ orig_mb } MiB has been adjusted
          to #{ mb } MiB in order to satisfy the limit of 10,000 chunks.
          To enforce your chosen #chunk_size, you should use the Splitter.
          e.g. split_into_chunks_of #{ mb * 10_000 } (#chunk_size * 10_000)
        EOS
        1024**2 * mb
      end

      class Object
        attr_reader :key, :etag, :storage_class

        def initialize(cloud_io, data)
          @cloud_io = cloud_io
          @key  = data['Key']
          @etag = data['ETag']
          @storage_class = data['StorageClass']
        end

        # currently 'AES256' or nil
        def encryption
          metadata['x-amz-server-side-encryption']
        end

        private

        def metadata
          @metadata ||= @cloud_io.head_object(self).headers
        end
      end

    end
  end
end
