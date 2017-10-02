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
            @uploader = DropboxApi::ChunkedUploader.new(client, file)
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
    end
  end
end
