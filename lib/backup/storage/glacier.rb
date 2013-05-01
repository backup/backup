# encoding: utf-8

Backup::Dependency.load('fog')

module Backup
  module Storage
    class Glacier < Base

      ##
      # Amazon Glacier Credentials
      attr_accessor :access_key_id, :secret_access_key

      ##
      # Amazon Glacier vault name
      attr_accessor :vault

      ##
      # Region of the specified Glacier vault
      attr_accessor :region

      # Must be a power of 2.
      # Min: 1 Max: 4000
      # Recommended: 4, 8, 16, 32, 64
      # Max number of chunks is 10,000, so max total file size for these
      # recommended values would range from 40 GiB to 640 GiB.
      # Lower is better in case of retries.
      # However, for large files and/or a reliable connection,
      # larger chunks means less requests (charged at ~ $0.05 per 1000).
      attr_accessor :chunk_size

      attr_accessor :max_retries, :retry_waitsec

      def initialize(model, storage_id = nil, &block)
        super
        instance_eval(&block) if block_given?

        @chunk_size     ||= 4 # MiB
        @max_retries    ||= 10
        @retry_waitsec  ||= 30
        # @path is not used with this storage
        @keep ||= 1 # must be set
      end

      private

      # Fog::AWS::Glacier does not support #sync_clock
      def connection
        @connection ||= Fog::AWS::Glacier.new(
          :aws_access_key_id      => access_key_id,
          :aws_secret_access_key  => secret_access_key,
          :region                 => region
        )
      end

      def transfer!
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          desc = "#{ package.time }-#{ filename }"
          Logger.info "Storing '#{ desc }' to vault '#{ vault }'..."
          uploader = Uploader.new(connection, vault, src, desc, chunk_size,
                                  max_retries, retry_waitsec)
          uploader.run
          package.metadata[filename] = { :archive_id => uploader.archive_id }
        end
      end

      # Called by the Cycler.
      # Any error raised will be logged as a warning.
      def remove!(package)
        Logger.info "Removing backup package dated #{ package.time }..."

        package.filenames.each do |filename|
          connection.delete_archive(vault, package.metadata[filename][:archive_id])
        end
      end

      class Uploader
        attr_reader :connection, :vault, :src, :desc
        attr_reader :chunk_size, :max_retries, :retry_waitsec
        attr_reader :file_size, :upload_id, :tree_hash, :archive_id

        def initialize(connection, vault, src, desc,
                       chunk_size, max_retries, retry_waitsec)
          @connection = connection
          @vault = vault
          @src = src
          @desc = desc
          @chunk_size = 1024**2 * chunk_size
          @max_retries = max_retries
          @retry_waitsec = retry_waitsec
          @tree_hash = Fog::AWS::Glacier::TreeHash.new
        end

        def run
          @file_size = File.size(src)

          if chunk_size > 0 && file_size > chunk_size
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
          data = File.read(src)
          with_retries do
            resp = connection.create_archive(vault, data, { 'description' => desc })
            @archive_id = resp.headers['x-amz-archive-id']
          end
        end

        def initiate_multipart
          with_retries do
            resp = connection.initiate_multipart_upload(
                vault, chunk_size, { 'description' => desc })
            @upload_id = resp.headers['x-amz-multipart-upload-id']
          end
        end

        def upload_parts
          File.open(src, 'r') do |file|
            offset = 0
            while data = file.read(chunk_size)
              hash = tree_hash.add_part(data)
              with_retries do
                connection.upload_part(vault, upload_id, data, offset, hash)
              end
              offset += chunk_size
            end
          end
        end

        def complete_multipart
          hash = tree_hash.hexdigest
          with_retries do
            resp = connection.complete_multipart_upload(
                vault, upload_id, file_size, hash)
            @archive_id = resp.headers['x-amz-archive-id']
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
        # includes `request.inspect`, which includes the String#inspect
        # output of `file.read(chunk_size)`.
        def error_with(err, msg)
          if err.is_a? Excon::Errors::HTTPStatusError
            Errors::Storage::Glacier::UploaderError.new(<<-EOS)
              #{ msg }
              Reason: #{ err.class }
              response => #{ err.response.inspect }
            EOS
          else
            Errors::Storage::Glacier::UploaderError.wrap(err, msg)
          end
        end
      end # class Uploader

    end
  end
end
