require 'dropbox_api'

module Backup
  module Storage
    class Dropbox < Base
      include Storage::Cycler
      class Error < Backup::Error; end

      ##
      # Dropbox API credentials
      attr_accessor :api_token

      ##
      # Chunk size, specified in MiB, for the ChunkedUploader.
      attr_accessor :chunk_size

      ##
      # Number of times to retry failed operations.
      #
      # Default: 10
      attr_accessor :max_retries

      ##
      # Time in seconds to pause before each retry.
      #
      # Default: 30
      attr_accessor :retry_waitsec

      ##
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil)
        super

        @path           ||= 'backups'
        @chunk_size     ||= 4 # MiB
        @max_retries    ||= 10
        @retry_waitsec  ||= 30
        path.sub!(/^\//, "")
      end

      private

      ##
      # The initial client in api V2 authorized by token
      def client
        return @client if @client
        @client = DropboxApi::Client.new(api_token)

      rescue => err
        raise Error.wrap(err, "Authorization Failed")
      end

      ##
      # Transfer each of the package files to Dropbox in chunks of +chunk_size+.
      # Each chunk will be retried +chunk_retries+ times, pausing +retry_waitsec+
      # between retries, if errors occur.
      def transfer!
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = File.join('/', remote_path, filename)
          Logger.info "Storing '#{ dest }'..."

          File.open(src, 'r') do |file|
            @uploader = ChunkedUploader.new(client, file)
            with_retries do
              @uploader.upload(1024**2 * chunk_size)
            end
          end

          with_retries do
            @uploader.finish(dest)
          end
        end
      rescue => err
        raise Error.wrap(err, "Upload Failed!")
      end

      def with_retries
        retries = 0
        begin
          yield
        rescue StandardError => err
          retries += 1
          raise if retries > max_retries

          Logger.info Error.wrap(err, "Retry ##{ retries } of #{ max_retries }.")
          sleep(retry_waitsec)
          retry
        end
      end

      # Called by the Cycler.
      # Any error raised will be logged as a warning.
      def remove!(package)
        Logger.info "Removing backup package dated #{package.time}..."

        client.delete("/#{remote_path_for(package)}")
      end

      class ChunkedUploader
        attr_accessor :file_object, :total_size, :cursor, :client

        def initialize(client, file_object)
          @client = client
          @file_object = file_object
          @total_size = file_object.stat.size
          @cursor = nil
        end

        # Uploads data from this ChunkedUploader's file_object in chunks, until
        # an error occurs. Throws an exception when an error occurs, and can
        # be called again to resume the upload.
        #
        # @param chunk_size [Integer] The chunk size for each individual upload.  Defaults to 4MB.
        def upload(chunk_size = 4 * 1024 * 1024)
          chunk = file_object.read(chunk_size)
          @cursor = client.upload_session_start(chunk)

          while cursor.offset < total_size
            begin
              chunk = file_object.read(chunk_size)
              client.upload_session_append_v2(cursor, chunk)
            rescue StandardError => err
              Error.wrap(err, "Uploader error")
            end
          end
        end

        # Completes a file upload
        #
        # Args:
        # @param path [String] The directory path to upload the file to. If the destination
        # directory does not yet exist, it will be created.
        # @param mode [String]
        def finish(path, mode = "overwrite")
          commit = DropboxApi::Metadata::CommitInfo.new(
            "path" => path,
            "mode" => mode
          )
          client.upload_session_finish(cursor, commit)
        end
      end
    end
  end
end
