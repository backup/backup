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
      # Creates a new instance of the Dropbox storage object
      # First it sets the defaults (if any exist) and then evaluates
      # the configuration block which may overwrite these defaults
      def initialize(&block)
        load_defaults!

        @path ||= 'backups'

        instance_eval(&block) if block_given?

        @timeout ||= 300
        @time = TIME
      end

      ##
      # This is the remote path to where the backup files will be stored
      def remote_path
        File.join(path, TRIGGER)
      end

      ##
      # Performs the backup transfer
      def perform!
        transfer!
        cycle!
      end

    private

      ##
      # The initial connection to Dropbox will provide the user with an authorization url.
      # The user must open this URL and confirm that the authorization successfully took place.
      # If this is the case, then the user hits 'enter' and the session will be properly established.
      # Immediately after establishing the session, the session will be serialized and written to a cache file
      # in Backup::CACHE_PATH. The cached file will be used from that point on to re-establish a connection with
      # Dropbox at a later time. This allows the user to avoid having to go to a new Dropbox URL to authorize over and over again.
      def connection
        if cache_exists?
          begin
            cached_session = ::Dropbox::Session.deserialize(File.read(cached_file))
            return cached_session if cached_session.authorized?
            Logger.warn "Cached session found, but the session was not authorized."
          rescue ArgumentError => error
            Logger.warn "Could not read from cache, data might be corrupt."
          end
        end

        Logger.message "Creating a new session!"
        create_write_and_return_new_session!
      end

      ##
      # Transfers the archived file to the specified Dropbox folder
      def transfer!
        Logger.message("#{ self.class } started transferring \"#{ remote_file }\".")
        connection.upload(File.join(local_path, local_file), remote_path, :timeout => timeout)
      end

      ##
      # Removes the transferred archive file from the Dropbox folder
      def remove!
        begin
          connection.delete(File.join(remote_path, remote_file))
        rescue ::Dropbox::FileNotFoundError
          Logger.warn "File \"#{ File.join(remote_path, remote_file) }\" does not exist, skipping removal."
        end
      end

      ##
      # Create a new session, write a serialized version of it to the
      # .cache directory, and return the session object
      def create_write_and_return_new_session!
        session      = ::Dropbox::Session.new(api_key, api_secret)
        session.mode = :dropbox
        Logger.message "Visit: #{session.authorize_url}"
        Logger.message "to authorize a session for your Dropbox account."
        Logger.message
        Logger.message "When you've successfully authorized the session, hit enter."
        Timeout::timeout(180) do
          gets
        end
        Logger.message "Authorizing.."
        begin
          session.authorize
        rescue OAuth::Unauthorized => error
          Logger.error "Authorization failed!"
          raise error
        end
        Logger.message "Authorized!"

        Logger.message "Caching session data to #{cached_file}.."
        write_cache!(session)
        Logger.message "Done! You will no longer need to manually authorize via an URL on this machine for this Dropbox account."
        Logger.message "Note: If you run Backup with Dropbox on other machines, you will need to authorize them to use your Dropbox account as well."

        session
      end

      ##
      # Returns the path to the cached file
      def cached_file
        File.join(Backup::CACHE_PATH, "#{api_key + api_secret}")
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

    public # DEPRECATED METHODS #############################################

      def email
        Logger.warn "[DEPRECATED] Backup::Storage::Dropbox.email is deprecated and will be removed at some point."
      end

      def email=(value)
        Logger.warn "[DEPRECATED] Backup::Storage::Dropbox.email= is deprecated and will be removed at some point."
      end

      def password
        Logger.warn "[DEPRECATED] Backup::Storage::Dropbox.password is deprecated and will be removed at some point."
      end

      def password=(value)
        Logger.warn "[DEPRECATED] Backup::Storage::Dropbox.password= is deprecated and will be removed at some point."
      end

    end
  end
end
