# encoding: utf-8
require 'dropbox_sdk'

module Backup
  module Storage
    class Dropbox < Base
      class Error < Backup::Error; end

      ##
      # Dropbox API credentials
      attr_accessor :api_key, :api_secret

      ##
      # Dropbox Access Type
      # Valid values are:
      #   :app_folder (default)
      #   :dropbox (full access)
      attr_accessor :access_type

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
        @access_type    ||= :app_folder
        @chunk_size     ||= 4 # MiB
        @max_retries    ||= 10
        @retry_waitsec  ||= 30
        path.sub!(/^\//, '')
      end

      private

      ##
      # The initial connection to Dropbox will provide the user with an
      # authorization url. The user must open this URL and confirm that the
      # authorization successfully took place. If this is the case, then the
      # user hits 'enter' and the session will be properly established.
      # Immediately after establishing the session, the session will be
      # serialized and written to a cache file in Backup::Config.cache_path.
      # The cached file will be used from that point on to re-establish a
      # connection with Dropbox at a later time. This allows the user to avoid
      # having to go to a new Dropbox URL to authorize over and over again.
      def connection
        return @connection if @connection

        unless session = cached_session
          Logger.info "Creating a new session!"
          session = create_write_and_return_new_session!
        end

        # will raise an error if session not authorized
        @connection = DropboxClient.new(session, access_type)

      rescue => err
        raise Error.wrap(err, 'Authorization Failed')
      end

      ##
      # Attempt to load a cached session
      def cached_session
        session = false
        if File.exist?(cached_file)
          begin
            session = DropboxSession.deserialize(File.read(cached_file))
            Logger.info "Session data loaded from cache!"

          rescue => err
            Logger.warn Error.wrap(err, <<-EOS)
              Could not read session data from cache.
              Cache data might be corrupt.
            EOS
          end
        end
        session
      end

      ##
      # Transfer each of the package files to Dropbox in chunks of +chunk_size+.
      # Each chunk will be retried +chunk_retries+ times, pausing +retry_waitsec+
      # between retries, if errors occur.
      def transfer!
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = File.join(remote_path, filename)
          Logger.info "Storing '#{ dest }'..."

          uploader = nil
          File.open(src, 'r') do |file|
            uploader = connection.get_chunked_uploader(file, file.stat.size)
            while uploader.offset < uploader.total_size
              with_retries do
                uploader.upload(1024**2 * chunk_size)
              end
            end
          end

          with_retries do
            uploader.finish(dest)
          end
        end

      rescue => err
        raise Error.wrap(err, 'Upload Failed!')
      end

      # Timeout::Error is not a StandardError under ruby-1.8.7
      def with_retries
        retries = 0
        begin
          yield
        rescue StandardError, Timeout::Error => err
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
        Logger.info "Removing backup package dated #{ package.time }..."

        connection.file_delete(remote_path_for(package))
      end

      def cached_file
        File.join(Config.cache_path, api_key + api_secret)
      end

      ##
      # Serializes and writes the Dropbox session to a cache file
      def write_cache!(session)
        FileUtils.mkdir_p(Config.cache_path)
        File.open(cached_file, "w") do |cache_file|
          cache_file.write(session.serialize)
        end
      end

      ##
      # Create a new session, write a serialized version of it to the
      # .cache directory, and return the session object
      def create_write_and_return_new_session!
        require 'timeout'

        session = DropboxSession.new(api_key, api_secret)

        # grab the request token for session
        session.get_request_token

        template = Backup::Template.new(
          {:session => session, :cached_file => cached_file}
        )
        template.render("storage/dropbox/authorization_url.erb")

        # wait for user to hit 'return' to continue
        Timeout::timeout(180) { STDIN.gets }

        # this will raise an error if the user did not
        # visit the authorization_url and grant access
        #
        # get the access token from the server
        # this will be stored with the session in the cache file
        session.get_access_token

        template.render("storage/dropbox/authorized.erb")
        write_cache!(session)
        template.render("storage/dropbox/cache_file_written.erb")

        session

      rescue => err
        raise Error.wrap(err, 'Could not create or authenticate a new session')
      end

      attr_deprecate :email,    :version => '3.0.17'
      attr_deprecate :password, :version => '3.0.17'
      attr_deprecate :timeout,  :version => '3.0.21'

      attr_deprecate :chunk_retries, :version => '3.7.0',
                     :message => 'Use #max_retries instead.',
                     :action => lambda {|klass, val| klass.max_retries = val }
    end
  end
end

# Patch for dropbox-ruby-sdk-1.5.1
class DropboxClient
  class ChunkedUploader
    def upload(chunk_size = 1024**2 * 4)
      while @offset < @total_size
        @file_obj.seek(@offset) unless @file_obj.pos == @offset
        data = @file_obj.read(chunk_size)

        begin
          resp = @client.parse_response(
            @client.partial_chunked_upload(data, @upload_id, @offset)
          )
        rescue DropboxError => err
          resp = JSON.parse(err.http_response.body) rescue {}
          raise err unless resp['offset']
        end

        @offset = resp['offset']
        @upload_id ||= resp['upload_id']
      end
    end
  end
end
