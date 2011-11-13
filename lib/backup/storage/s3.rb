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
      # This is the remote path to where the backup files will be stored
      def remote_path
        File.join(path, TRIGGER, @time).sub(/^\//, '')
      end

      ##
      # This is the provider that Fog uses for the S3 Storage
      def provider
        'AWS'
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
      end

      ##
      # Establishes a connection to Amazon S3 and returns the Fog object.
      # Not doing any instance variable caching because this object gets persisted in YAML
      # format to a file and will issues. This, however has no impact on performance since it only
      # gets invoked once per object for a #transfer! and once for a remove! Backups run in the
      # background anyway so even if it were a bit slower it shouldn't matter.
      def connection
        Fog::Storage.new(
          :provider               => provider,
          :aws_access_key_id      => access_key_id,
          :aws_secret_access_key  => secret_access_key,
          :region                 => region
        )
      end

      ##
      # Transfers the archived file to the specified Amazon S3 bucket
      def transfer!
        connection.sync_clock
        files_to_transfer do |local_file, remote_file|
          Logger.message("#{ self.class } started transferring '#{ local_file }' to bucket '#{ bucket }'")
          connection.put_object(
            bucket,
            File.join(remote_path, remote_file),
            File.open(File.join(local_path, local_file))
          )
        end
      end

      ##
      # Removes the transferred archive file from the Amazon S3 bucket
      def remove!
        connection.sync_clock
        transferred_files do |local_file, remote_file|
          Logger.message("#{ self.class } started removing '#{ local_file }' from bucket '#{ bucket }'")
          connection.delete_object(bucket, File.join(remote_path, remote_file))
        end
      end

    end
  end
end
