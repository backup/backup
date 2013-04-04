# encoding: utf-8

##
# Only load the Fog gem when the Backup::Storage::HPCloud class is loaded
Backup::Dependency.load('fog')

module Backup
  module Storage
    class HPCloud < Base

      ##
      # HPCloud Object Storage Service Credentials
      attr_accessor :hp_access_key, :hp_secret_key, :hp_tenant_id

      ##
      # HPCloud Object Storage Service Auth Url and Availability Zone
      attr_accessor :hp_auth_uri, :hp_avl_zone

      ##
      # HPCloud Object Storage container name and path
      attr_accessor :container, :path

      ##
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil, &block)
        super(model, storage_id)

        @path ||= 'backups'

        instance_eval(&block) if block_given?
      end

      private

      ##
      # This is the provider that Fog uses for the HPCloud Object Storage service
      def provider
        'HP'
      end

      ##
      # Establishes a connection to HPCloud Object Storage
      def connection
        @connection ||= Fog::Storage.new(
          :provider       => provider,
          :hp_access_key  => hp_access_key,
          :hp_secret_key  => hp_secret_key,
          :hp_auth_uri    => hp_auth_uri || "https://region-a.geo-1.identity.hpcloudsvc.com:35357/v2.0/tokens",
          :hp_tenant_id   => hp_tenant_id,
          :hp_avl_zone    => hp_avl_zone || "region-a.geo-1"
        )
      end

      ##
      # Queries the connection for the directory for the given +remote_path+
      # Returns nil if not found, or creates the directory if +create+ is true.
      def directory_for(remote_path, create = false)
        directory = connection.directories.get(remote_path)
        if directory.nil? && create
          directory = connection.directories.create(:key => remote_path)
        end
        directory
      end

      def remote_path_for(package)
        super(package).sub(/^\//, '')
      end

      ##
      # Transfers the archived file to the specified HPCloud Object Storage container
      def transfer!
        remote_path = remote_path_for(@package)

        directory = directory_for(remote_path, true)

        files_to_transfer_for(@package) do |local_file, remote_file|
          Logger.info "#{storage_name} started transferring '#{ local_file }'."

          File.open(File.join(local_path, local_file), 'r') do |file|
            directory.files.create(:key => remote_file, :body => file)
          end
        end
      end

      ##
      # Removes the transferred archive file(s) from the storage location.
      # Any error raised will be rescued during Cycling
      # and a warning will be logged, containing the error message.
      def remove!(package)
        remote_path = remote_path_for(package)

        if directory = directory_for(remote_path)
          not_found = []

        transferred_files_for(package) do |local_file, remote_file|
          Logger.info "#{storage_name} started removing " +
              "'#{ local_file }' from HPCloud."

          if file = directory.files.get(remote_file)
            file.destroy
          else
            not_found << remote_file
          end

        end
          directory.destroy

          unless not_found.empty?
            raise Errors::Storage::HPCloud::NotFoundError, <<-EOS
                The following file(s) were not found in '#{ remote_path }'
                #{ not_found.join("\n") }
            EOS
          end
        else
          raise Errors::Storage::HPCloud::NotFoundError,
              "Directory at '#{remote_path}' not found"
        end
      end

    end
  end
end
