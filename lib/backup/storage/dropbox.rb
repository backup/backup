# encoding: utf-8

##
# Only load the Dropbox gem when the Backup::Storage::Dropbox class is loaded
Backup::Dependency.load('dropbox')

##
# Only load the timeout library when the Backup::Storage::Dropbox class is loaded
require 'timeout'

module Backup
  module Storage
    class Dropbox < Base

      ##
      # Dropbox API credentials
      attr_accessor :api_key, :api_secret

      ##
      # Path to where the backups will be stored
      attr_accessor :path

      ##
      # Dropbox connection timeout
      attr_accessor :timeout

      ##
      # This is the remote path to where the backup files will be stored
      def remote_path
        File.join(path, TRIGGER, @time)
      end

      ##
      # Performs the backup transfer
      def perform!
        super
        transfer!
        cycle!
      end

    private

      ##
      # Set configuration defaults before evaluating configuration block,
      # after setting defaults from Storage::Base
      def pre_configure
        super
        @path ||= 'backups'
      end

      ##
      # Adjust configuration after evaluating configuration block,
      # after adjustments from Storage::Base
      def post_configure
        super
        @timeout ||= 300
      end

      ##
      # The initial connection to Dropbox will provide the user with an authorization url.
      # The user must open this URL and confirm that the authorization successfully took place.
      # If this is the case, then the user hits 'enter' and the session will be properly established.
      # Immediately after establishing the session, the session will be serialized and written to a cache file
      # in Backup::CACHE_PATH. The cached file will be used from that point on to re-establish a connection with
      # Dropbox at a later time. This allows the user to avoid having to go to a new Dropbox URL to authorize over and over again.
      def connection
        return @connection if @connection

        if cache_exists?
          begin
            cached_session = ::Dropbox::Session.deserialize(File.read(cached_file))
            if cached_session.authorized?
              Logger.message "Session data loaded from cache!"
              return @connection = cached_session
            end
          rescue ArgumentError => error
            Logger.warn "Could not read session data from cache. Cache data might be corrupt."
          end
        end

        Logger.message "Creating a new session!"
        create_write_and_return_new_session!
      end

      ##
      # Transfers the archived file to the specified Dropbox folder
      def transfer!
        files_to_transfer do |local_file, remote_file|
          Logger.message("#{ self.class } started transferring \"#{ local_file }\".")
          connection.upload(
            File.join(local_path, local_file),
            remote_path,
            :as      => remote_file,
            :timeout => timeout
          )
        end

        remove_instance_variable(:@connection) if instance_variable_defined?(:@connection)
      end

      ##
      # Removes the transferred archive file from the Dropbox folder
      def remove!
        transferred_files do |local_file, remote_file|
          Logger.message("#{ self.class } started removing '#{ local_file }' from Dropbox.'")
        end

        connection.delete(remote_path)
      ensure
        remove_instance_variable(:@connection) if instance_variable_defined?(:@connection)
      end

      ##
      # Returns the path to the cached file
      def cached_file
        File.join(Backup::CACHE_PATH, api_key + api_secret)
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
        session      = ::Dropbox::Session.new(api_key, api_secret)
        session.mode = :dropbox

        template = Backup::Template.new({:session => session, :cached_file => cached_file})
        template.render("storage/dropbox/authorization_url.erb")

        begin
          Timeout::timeout(180) { STDIN.gets }
          session.authorize
        rescue OAuth::Unauthorized => error
          Logger.error "Authorization failed!"
          raise error
        end

        template.render("storage/dropbox/authorized.erb")
        write_cache!(session)
        template.render("storage/dropbox/cache_file_written.erb")

        session
      end

    end
  end
end
