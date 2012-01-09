# encoding: utf-8

##
# Only load the Fog gem when the Backup::Storage::S3 class is loaded
Backup::Dependency.load('fog')

module Backup
  module Storage
    class S3 < Base

      ##
      # Amazon Simple Storage Service (S3) Credentials
      attr_accessor :access_key_id, :secret_access_key

      ##
      # Amazon S3 bucket name and path
      attr_accessor :bucket, :path

      ##
      # Region of the specified S3 bucket
      attr_accessor :region

      ##
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil, &block)
        super(model, storage_id)

        @path ||= 'backups'

        instance_eval(&block) if block_given?
      end

      private

      ##
      # This is the provider that Fog uses for the S3 Storage
      def provider
        'AWS'
      end

      ##
      # Establishes a connection to Amazon S3
      def connection
        @connection ||= Fog::Storage.new(
          :provider               => provider,
          :aws_access_key_id      => access_key_id,
          :aws_secret_access_key  => secret_access_key,
          :region                 => region
        )
      end

      def remote_path_for(package)
        super(package).sub(/^\//, '')
      end

      ##
      # Transfers the archived file to the specified Amazon S3 bucket
      def transfer!
        remote_path = remote_path_for(@package)

        connection.sync_clock

        files_to_transfer_for(@package) do |local_file, remote_file|
          Logger.message "#{storage_name} started transferring " +
              "'#{ local_file }' to bucket '#{ bucket }'."

          File.open(File.join(local_path, local_file), 'r') do |file|
            connection.put_object(
              bucket, File.join(remote_path, remote_file), file
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

        connection.sync_clock

        transferred_files_for(package) do |local_file, remote_file|
          Logger.message "#{storage_name} started removing " +
              "'#{ local_file }' from bucket '#{ bucket }'."

          connection.delete_object(bucket, File.join(remote_path, remote_file))
        end
      end

    end
  end
end
