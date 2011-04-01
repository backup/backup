# encoding: utf-8

##
# Only load the Dropbox gem when the Backup::Storage::Dropbox class is loaded
Backup::Dependency.load('dropbox')

module Backup
  module Storage
    class Dropbox < Base

      ##
      # Dropbox user credentials
      attr_accessor :email, :password

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
      # Establishes a connection to Dropbox and returns the Dropbox::Session object.
      # Not doing any instance variable caching because this object gets persisted in YAML
      # format to a file and will issues. This, however has no impact on performance since it only
      # gets invoked once per object for a #transfer! and once for a remove! Backups run in the
      # background anyway so even if it were a bit slower it shouldn't matter.
      def connection
        session                      = ::Dropbox::Session.new(api_key, api_secret)
        session.mode                 = :dropbox
        session.authorizing_user     = email
        session.authorizing_password = password
        session.authorize!
        session
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

    end
  end
end
