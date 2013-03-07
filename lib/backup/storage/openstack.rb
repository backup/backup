# encoding: utf-8

##
# Only load the Fog gem when the Backup::Storage::OpenStack class is loaded
Backup::Dependency.load('fog')

module Backup
  module Storage
    class OpenStack < Base

      ##
      # OpenStack credentials
      attr_accessor :username, :api_key, :auth_url

      ##
      # OpenStack storage container name and path
      attr_accessor :container, :path

      ##
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil, &block)
        super(model, storage_id)

        @path       ||= 'backups'

        instance_eval(&block) if block_given?
      end

      protected

      ##
      # This is the provider that Fog uses
      def provider
        'Openstack'
      end

      ##
      # Establishes a connection
      def connection
        @connection ||= Fog::Storage.new(
          :provider             => provider,
          :openstack_username   => username,
          :openstack_api_key    => api_key,
          :openstack_auth_url   => auth_url
        )
      end

      ##
      # Transfers the archived file to the specified container
      def transfer!
        remote_path = remote_path_for(@package)

        files_to_transfer_for(@package) do |local_file, remote_file|
          Logger.info "#{storage_name} started transferring '#{ local_file }'."

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
          Logger.info "#{storage_name} started removing '#{ local_file }' " +
              "from container '#{ container }'."
          connection.delete_object(container, File.join(remote_path, remote_file))
        end
      end

    end
  end
end
