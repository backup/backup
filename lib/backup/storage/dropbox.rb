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

      # Deprecated as of v3.0.21 - for move to official 'dropbox-sdk' gem (v1.1)
      def timeout=(value)
        if value
          Logger.warn "[DEPRECATED] Backup::Storage::Dropbox.timeout=\n" +
              "  is deprecated and will be removed at some point."
        end
      end

      ##
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil, &block)
        super(model, storage_id)

        @path ||= 'backups'
        @access_type ||= :app_folder

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
          Logger.message "Creating a new session!"
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
            Logger.message "Session data loaded from cache!"

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
      def transfer!
        remote_path = remote_path_for(@package)

        files_to_transfer_for(@package) do |local_file, remote_file|
          Logger.message "#{storage_name} started transferring '#{ local_file }'."
          File.open(File.join(local_path, local_file), 'r') do |file|
            connection.put_file(File.join(remote_path, remote_file), file)
          end
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
        Logger.message messages.join("\n")

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
