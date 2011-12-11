# encoding: utf-8

##
# Only load the Fog gem when the Backup::Storage::CloudFiles class is loaded
Backup::Dependency.load('fog')

module Backup
  module Storage
    class CloudFiles < Base

      ##
      # Rackspace Cloud Files Credentials
      attr_accessor :username, :api_key, :auth_url

      ##
      # Rackspace Service Net (Allows for LAN-based transfers to avoid charges and improve performance)
      attr_accessor :servicenet

      ##
      # Rackspace Cloud Files container name and path
      attr_accessor :container, :path

      ##
      # This is the remote path to where the backup files will be stored
      def remote_path
        File.join(path, TRIGGER, @time)
      end

      ##
      # This is the provider that Fog uses for the Cloud Files Storage
      def provider
        'Rackspace'
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
        @servicenet ||= false
        @path       ||= 'backups'
      end

      ##
      # Adjust configuration after evaluating configuration block,
      # after adjustments from Storage::Base
      def post_configure
        super
      end

      ##
      # Establishes a connection to Rackspace Cloud Files and returns the Fog object.
      # Not doing any instance variable caching because this object gets persisted in YAML
      # format to a file and will issues. This, however has no impact on performance since it only
      # gets invoked once per object for a #transfer! and once for a remove! Backups run in the
      # background anyway so even if it were a bit slower it shouldn't matter.
      def connection
        Fog::Storage.new(
          :provider             => provider,
          :rackspace_username   => username,
          :rackspace_api_key    => api_key,
          :rackspace_auth_url   => auth_url,
          :rackspace_servicenet => servicenet
        )
      end

      ##
      # Transfers the archived file to the specified Cloud Files container
      def transfer!
        files_to_transfer do |local_file, remote_file|
          Logger.message "#{ self.class } started transferring '#{ local_file }'."
          connection.put_object(
            container,
            File.join(remote_path, remote_file),
            File.open(File.join(local_path, local_file))
          )
        end
      end

      ##
      # Removes the transferred archive file from the Cloud Files container
      def remove!
        transferred_files do |local_file, remote_file|
          Logger.message "#{ self.class } started removing '#{ local_file }'" +
              "from container '#{ container }'"
          connection.delete_object(container, File.join(remote_path, remote_file))
        end
      end

    end
  end
end
