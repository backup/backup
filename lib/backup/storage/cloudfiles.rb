# encoding: utf-8

##
# Only load the Fog gem when the Backup::Storage::CloudFiles class is loaded
Backup::Dependency.load('fog')

module Backup
  module Storage
    class CloudFiles < Base

      ##
      # OpenStack Object Storage Credentials
      attr_accessor :username, :api_key, :auth_url

      ##
      # Rackspace Service Net
      # (LAN-based transfers to avoid charges and improve performance)
      attr_accessor :servicenet

      ##
      # OpenStack Object Storage container name and path
      attr_accessor :container, :path

      ##
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil, &block)
        super(model, storage_id)

        @servicenet ||= false
        @path       ||= 'backups'

        instance_eval(&block) if block_given?
      end

      private

      ##
      # This is the provider that Fog uses for the Cloud Files Storage
      def provider
        'Rackspace'
      end

      ##
      # Establishes a connection to Rackspace Cloud Files
      def connection
        @connection ||= Fog::Storage.new(
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
        remote_path = remote_path_for(@package)

        files_to_transfer_for(@package) do |local_file, remote_file|
          Logger.message "#{storage_name} started transferring '#{ local_file }'."

          File.open(File.join(local_path, local_file), 'r') do |file|
            connection.put_object(
              container, File.join(remote_path, remote_file), file
            )
          end
        end
      end

      ##
      # Removes the transferred archive file(s) from the storage location.
      # Any error raised will be rescued during Cycling
      # and a warning will be logged, containing the error message.
      def remove!(package)
        remote_path = remote_path_for(package)

        transferred_files_for(package) do |local_file, remote_file|
          Logger.message "#{storage_name} started removing '#{ local_file }' " +
              "from container '#{ container }'."
          connection.delete_object(container, File.join(remote_path, remote_file))
        end
      end

    end
  end
end
