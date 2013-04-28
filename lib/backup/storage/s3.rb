# encoding: utf-8

Backup::Dependency.load('fog')
require 'base64'
require 'digest/md5'

module Backup
  module Storage
    class S3 < Base

      ##
      # Amazon Simple Storage Service (S3) Credentials
      attr_accessor :access_key_id, :secret_access_key

      ##
      # Amazon S3 bucket name
      attr_accessor :bucket

      ##
      # Region of the specified S3 bucket
      attr_accessor :region

      ##
      # Chunk size, specified in MiB, for S3 Multipart Upload.
      #
      # Each backup package file that is greater than +chunk_size+
      # will be uploaded using AWS' Multipart Upload.
      #
      # Package files less than or equal to +chunk_size+ will be
      # uploaded via a single PUT request.
      #
      # Minimum allowed: 5 (but may be disabled with 0)
      # Default: 5
      attr_accessor :chunk_size

      ##
      # Number of times to retry failed operations.
      #
      # The retry count is reset when the failing operation succeeds,
      # so each operation that fails will be retried this number of times.
      # Once a single failed operation exceeds +max_retries+, the entire
      # storage operation will fail.
      #
      # Operations that may fail and be retried include:
      # - Multipart initiation requests.
      # - Each multipart upload of +chunk_size+. (retries the chunk)
      # - Multipart upload completion requests.
      # - Each file uploaded not using multipart upload. (retries the file)
      #
      # Default: 10
      attr_accessor :max_retries

      ##
      # Time in seconds to pause before each retry.
      #
      # Default: 30
      attr_accessor :retry_waitsec

      def initialize(model, storage_id = nil, &block)
        super
        instance_eval(&block) if block_given?

        @chunk_size     ||= 5 # MiB
        @max_retries    ||= 10
        @retry_waitsec  ||= 30
        @path           ||= 'backups'
        path.sub!(/^\//, '')
      end

      private

      def connection
        @connection ||= begin
          conn = Fog::Storage.new(
            :provider               => 'AWS',
            :aws_access_key_id      => access_key_id,
            :aws_secret_access_key  => secret_access_key,
            :region                 => region
          )
          conn.sync_clock
          conn
        end
      end

      def transfer!
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = File.join(remote_path, filename)
          Logger.info "Storing '#{ bucket }/#{ dest }'..."
          Uploader.new(connection, bucket, src, dest,
                       chunk_size, max_retries, retry_waitsec).run
        end
      end

      # Called by the Cycler.
      # Any error raised will be logged as a warning.
      def remove!(package)
        Logger.info "Removing backup package dated #{ package.time }..."

        remote_path = remote_path_for(package)
        resp = connection.get_bucket(bucket, :prefix => remote_path)
        keys = resp.body['Contents'].map {|entry| entry['Key'] }

        raise Errors::Storage::S3::NotFoundError,
            "Package at '#{ remote_path }' not found" if keys.empty?

        connection.delete_multiple_objects(bucket, keys)
      end

      class Uploader
        attr_reader :connection, :bucket, :src, :dest
        attr_reader :chunk_size, :max_retries, :retry_waitsec
        attr_reader :upload_id, :parts

        def initialize(connection, bucket, src, dest,
                       chunk_size, max_retries, retry_waitsec)
          @connection = connection
          @bucket = bucket
          @src = src
          @dest = dest
          @chunk_size = 1024**2 * chunk_size
          @max_retries = max_retries
          @retry_waitsec = retry_waitsec
          @parts = []
        end

        def run
          if chunk_size > 0 && File.size(src) > chunk_size
            initiate_multipart
            upload_parts
            complete_multipart
          else
            upload
          end
        rescue => err
          raise error_with(err, 'Upload Failed!')
        end

        private

        def upload
          md5 = Base64.encode64(Digest::MD5.file(src).digest).chomp
          with_retries do
            File.open(src, 'r') do |file|
              connection.put_object(bucket, dest, file, { 'Content-MD5' => md5 })
            end
          end
        end

        def initiate_multipart
          with_retries do
            resp = connection.initiate_multipart_upload(bucket, dest)
            @upload_id = resp.body['UploadId']
          end
        end

        def upload_parts
          File.open(src, 'r') do |file|
            part_number = 0
            while data = file.read(chunk_size)
              part_number += 1
              md5 = Base64.encode64(Digest::MD5.digest(data)).chomp
              with_retries do
                resp = connection.upload_part(
                  bucket, dest, upload_id, part_number, data,
                  { 'Content-MD5' => md5 }
                )
                parts << resp.headers['ETag']
              end
            end
          end
        end

        def complete_multipart
          with_retries do
            connection.complete_multipart_upload(bucket, dest, upload_id, parts)
          end
        end

        def with_retries
          retries = 0
          begin
            yield
          rescue => err
            retries += 1
            raise if retries > max_retries

            Logger.info error_with(err, "Retry ##{ retries } of #{ max_retries }.")
            sleep(retry_waitsec)
            retry
          end
        end

        # Avoid wrapping Excon::Errors::HTTPStatusError since it's message
        # includes `request.inspect`. For multipart uploads, this includes
        # the String#inspect output of `file.read(chunk_size)`.
        def error_with(err, msg)
          if err.is_a? Excon::Errors::HTTPStatusError
            Errors::Storage::S3::UploaderError.new(<<-EOS)
              #{ msg }
              Reason: #{ err.class }
              response => #{ err.response.inspect }
            EOS
          else
            Errors::Storage::S3::UploaderError.wrap(err, msg)
          end
        end
      end # class Uploader

    end
  end
end
