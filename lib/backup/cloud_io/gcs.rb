# encoding: utf-8
require "backup/cloud_io/base"
require "fog"

module Backup
  module CloudIO
    class GCS < Base
      class Error < Backup::Error; end

      MAX_FILE_SIZE = 1024**5 * 5 # 5 TiB

      attr_reader :google_storage_access_key_id, :google_storage_secret_access_key,
        :bucket, :fog_options

      def initialize(options = {})
        super

        @google_storage_access_key_id     = options[:google_storage_access_key_id]
        @google_storage_secret_access_key = options[:google_storage_secret_access_key]
        @bucket                           = options[:bucket]
        @fog_options                      = options[:fog_options]
      end

      # The Syncer may call this method in multiple threads.
      # However, #objects is always called prior to multithreading.
      def upload(src, dest)
        file_size = File.size(src)
        raise FileSizeError, <<-EOS if file_size > MAX_FILE_SIZE
            File Too Large
            File: #{src}
            Size: #{file_size}
            Max File Size is #{MAX_FILE_SIZE} (5 GiB)
          EOS

        put_object(src, dest)
      end

      # Returns all objects in the bucket with the given prefix.
      #
      # - #get_bucket returns a max of 1000 objects per request.
      # - Returns objects in alphabetical order.
      # - If marker is given, only objects after the marker are in the response.
      def objects(prefix)
        objects = []
        resp = nil
        prefix = prefix.chomp("/")
        opts = { "prefix" => prefix + "/" }

        while resp.nil? || resp.body["IsTruncated"]
          opts["marker"] = objects.last.key unless objects.empty?
          with_retries("GET '#{bucket}/#{prefix}/*'") do
            resp = connection.get_bucket(bucket, opts)
          end
          resp.body["Contents"].each do |obj_data|
            objects << Object.new(self, obj_data)
          end
        end

        objects
      end

      # Delete object(s) from the bucket.
      #
      # - Called by the Storage (with objects) and the Syncer (with keys)
      # - Missing objects will be ignored.
      def delete(objects_or_keys)
        keys = Array(objects_or_keys).dup
        keys.map!(&:key) if keys.first.is_a?(Object)
        keys.each do |key|
          with_retries("DELETE object") do
            begin
              connection.delete(bucket, key)
            rescue StandardError => e
              raise Error, "The server returned the following:\n#{e.message}"
            end
          end
        end
      end

      private

      def connection
        @connection ||=
          begin
            opts = { provider: "Google",
                     google_storage_access_key_id: google_storage_access_key_id,
                     google_storage_secret_access_key: google_storage_secret_access_key }

            opts.merge!(fog_options || {})
            conn = Fog::Storage.new(opts)
            conn
          end
      end

      def put_object(src, dest)
        md5 = Base64.encode64(Digest::MD5.file(src).digest).chomp
        options = { "Content-MD5" => md5 }
        with_retries("PUT '#{bucket}/#{dest}'") do
          File.open(src, "r") do |file|
            begin
              connection.put_object(bucket, dest, file, options)
            rescue StandardError => e
              raise Error, "The server returned the following:\n#{e.message}\n"
            end
          end
        end
      end

      class Object
        attr_reader :key, :etag, :storage_class

        def initialize(cloud_io, data)
          @cloud_io = cloud_io
          @key  = data["Key"]
          @etag = data["ETag"]
          @storage_class = data["StorageClass"]
        end
      end
    end
  end
end
