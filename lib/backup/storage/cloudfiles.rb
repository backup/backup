# encoding: utf-8

##
# Only load the Fog gem when the Backup::Storage::CloudFiles class is loaded
Backup::Dependency.load('fog')

module Backup
  module Storage
    class CloudFiles < Base

      ##
      # Rackspace Cloud Files Credentials
      attr_accessor :username, :api_key

      ##
      # Rackspace Cloud Files container name and path
      attr_accessor :container, :path

      ##
      # Creates a new instance of the Rackspace Cloud Files storage object
      # First it sets the defaults (if any exist) and then evaluates
      # the configuration block which may overwrite these defaults
      def initialize(&block)
        load_defaults!

        @path ||= 'backups'

        instance_eval(&block) if block_given?

        @time = TIME
      end

      ##
      # This is the remote path to where the backup files will be stored
      def remote_path
        File.join(path, TRIGGER)
      end

      ##
      # This is the provider that Fog uses for the Cloud Files Storage
      def provider
        'Rackspace'
      end

      ##
      # Performs the backup transfer
      def perform!
        transfer!
        cycle!
      end

    private

      ##
      # Establishes a connection to Rackspace Cloud Files and returns the Fog object.
      # Not doing any instance variable caching because this object gets persisted in YAML
      # format to a file and will issues. This, however has no impact on performance since it only
      # gets invoked once per object for a #transfer! and once for a remove! Backups run in the
      # background anyway so even if it were a bit slower it shouldn't matter.
      def connection
        Fog::Storage.new(
          :provider           => provider,
          :rackspace_username => username,
          :rackspace_api_key  => api_key
        )
      end

      ##
      # Transfers the archived file to the specified Cloud Files container
      def transfer!
        begin
          Logger.message("#{ self.class } started transferring files to #{ provider }.")
          c = connection
          local_files.each do |local_file|
            Logger.message("#{ self.class } started transferring \"#{ local_file }\" to #{ provider }")
            c.put_object( container,
                          File.join(remote_path, remote_files.shift),
                          File.join(local_path, local_file)
            )
          end
        rescue Excon::Errors::SocketError => e
          puts "\nAn error occurred while trying to transfer the backup."
          puts "Make sure the container exists and try again.\n\n"
          exit
        end
      end

      ##
      # Removes the transferred archive file(s) from the Cloud Files container
      def remove!
        create_remote_file_list
        c = connection
        remote_files.each do |remote_file|
          Logger.message("#{ self.class } removing #{ remote_file } from #{ provider }")
          begin
            c.delete_object(container, File.join(remote_path, remote_file))
          rescue Excon::Errors::SocketError; end
        end
      end

    end
  end
end
