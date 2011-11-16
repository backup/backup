# encoding: utf-8

##
# Only load the Fog gem when the Backup::Storage::Ninefold class is loaded
Backup::Dependency.load('fog')

module Backup
  module Storage
    class Ninefold < Base

      ##
      # Ninefold Credentials
      attr_accessor :storage_token, :storage_secret

      ##
      # Ninefold directory path
      attr_accessor :path

      ##
      # Creates a new instance of the Ninefold storage object
      # First it sets the defaults (if any exist) and then evaluates
      # the configuration block which may overwrite these defaults
      #
      def initialize(&block)
        load_defaults!

        @path ||= 'backups'

        instance_eval(&block) if block_given?

        @time = TIME
      end

      ##
      # This is the remote path to where the backup files will be stored
      def remote_path
        File.join(path, TRIGGER, @time).sub(/^\//, '')
      end

      ##
      # This is the provider that Fog uses for the Ninefold storage
      def provider
        'Ninefold'
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
      # Establishes a connection to Amazon S3 and returns the Fog object.
      # Not doing any instance variable caching because this object gets persisted in YAML
      # format to a file and will issues. This, however has no impact on performance since it only
      # gets invoked once per object for a #transfer! and once for a remove! Backups run in the
      # background anyway so even if it were a bit slower it shouldn't matter.
      def connection
        Fog::Storage.new(
          :provider                => provider,
          :ninefold_storage_token  => storage_token,
          :ninefold_storage_secret => storage_secret
        )
      end

      ##
      # Transfers the archived file to the specified directory
      def transfer!
        files_to_transfer do |local_file, remote_file|
          Logger.message("#{ self.class } started transferring \"#{ local_file }\".")
          directory   = connection.directories.get(remote_path)
          directory ||= connection.directories.create(:key => remote_path)
          directory.files.create(
            :key  => remote_file,
            :body => File.open(File.join(local_path, local_file))
          )
        end
      rescue Excon::Errors::NotFound
        raise "An error occurred while trying to transfer the file."
      end

      ##
      # Removes the transferred archive file from the Amazon S3 bucket
      def remove!
        directory = connection.directories.get(remote_path)
        transferred_files do |local_file, remote_file|
          Logger.message("#{ self.class } started removing '#{ local_file }' from Ninefold.'")
          directory.files.get(remote_file).destroy
        end
        directory.destroy
        rescue Excon::Errors::SocketError
      end

    end
  end
end
