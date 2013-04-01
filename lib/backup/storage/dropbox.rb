# encoding: utf-8

##
# Only load the Dropbox gem when the Backup::Storage::Dropbox class is loaded
Backup::Dependency.load('dropbox-sdk')

module Backup
  module Storage
    class Dropbox < Base

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
      # Path to where the backups will be stored
      attr_accessor :path

      ##
      # chunk size for the DropboxClient::ChunkedUploader
      # specified in bytes
      attr_accessor :chunk_size, :chunk_retries, :retry_waitsec

      attr_deprecate :email,    :version => '3.0.17'
      attr_deprecate :password, :version => '3.0.17'

      attr_deprecate :timeout, :version => '3.0.21'

      ##
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil, &block)
        super(model, storage_id)

        @path ||= 'backups'
        @access_type ||= :app_folder
        # 4Mb in bytes
        @chunk_size ||= 1024 ** 2 * 4
        @chunk_retries ||= 10
        @retry_waitsec ||= 30

        instance_eval(&block) if block_given?
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
        raise Errors::Storage::Dropbox::ConnectionError.wrap(err)
      end

      ##
      # Attempt to load a cached session
      def cached_session
        session = false
        if cache_exists?
          begin
            session = DropboxSession.deserialize(File.read(cached_file))
            Logger.info "Session data loaded from cache!"

          rescue => err
            Logger.warn Errors::Storage::Dropbox::CacheError.wrap(err, <<-EOS)
              Could not read session data from cache.
              Cache data might be corrupt.
            EOS
          end
        end
        session
      end

      ##
      # Transfers the archived file to the specified Dropbox folder
      # in chunks of chunk_size
      def transfer!
        remote_path = remote_path_for(@package)
        files_to_transfer_for(@package) do |local_file, remote_file|
          Backup::Logger.info "#{storage_name} started transferring '#{ local_file }'."
          local_file_path = File.join(local_path, local_file)
          remote_file_path = File.join(remote_path, remote_file)
          file = File.open(local_file_path, "r")
          file_size = File.size(local_file_path)
          # Initialize the chunked_uploader
          uploader = connection.get_chunked_uploader(file, file_size )
          retries = 0
          # Start transferring chunks, retry on DropboxError chunk_retries times
          # sleep retry_waitsec seconds before next attempt
          while uploader.offset < uploader.total_size
            begin
              uploader.upload(chunk_size)
              retries = 0
            rescue => dbox_err
              retries += 1
              Backup::Logger.info "Dropbox chunk retry #{ retries } of #{ chunk_retries }." if chunk_retries > 0 # shouldn't say anything if no retries
              sleep(retry_waitsec)
              retry unless retries >= chunk_retries
              raise Errors::Storage::Dropbox::TransferError.
                wrap(dbox_err, 'Dropbox upload failed!')
            end
          end
          uploader.finish(remote_file_path)
        end
      end

      ##
      # Removes the transferred archive file(s) from the storage location.
      # Any error raised will be rescued during Cycling
      # and a warning will be logged, containing the error message.
      def remove!(package)
        remote_path = remote_path_for(package)

        messages = []
        transferred_files_for(package) do |local_file, remote_file|
          messages << "#{storage_name} started removing " +
              "'#{ local_file }' from Dropbox."
        end
        Logger.info messages.join("\n")

        connection.file_delete(remote_path)
      end

      ##
      # Returns the path to the cached file
      def cached_file
        File.join(Config.cache_path, api_key + api_secret)
      end

      ##
      # Checks to see if the cache file exists
      def cache_exists?
        File.exist?(cached_file)
      end

      ##
      # Serializes and writes the Dropbox session to a cache file
      def write_cache!(session)
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
          raise Errors::Storage::Dropbox::AuthenticationError.wrap(
            err, 'Could not create or authenticate a new session'
          )
      end

    end
  end
end
