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
      # Creates a new instance of the Amazon S3 storage object
      # First it sets the defaults (if any exist) and then evaluates
      # the configuration block which may overwrite these defaults
      #
      # Currently available regions:
      #   eu-west-1, us-east-1, ap-southeast-1, us-west-1
      def initialize(&block)
        load_defaults!

        @path ||= 'backups'

        instance_eval(&block) if block_given?

        @time = TIME
      end

      ##
      # This is the remote path to where the backup files will be stored
      def remote_path
        File.join(path, TRIGGER).sub(/^\//, '')
      end

      ##
      # This is the provider that Fog uses for the S3 Storage
      def provider
        'AWS'
      end

      ##
      # Performs the backup transfer
      def perform!
        create_bucket! unless bucket_exists?
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
          :provider               => provider,
          :aws_access_key_id      => access_key_id,
          :aws_secret_access_key  => secret_access_key,
          :region                 => region
        )
      end
      
      ##
      # Checks to see if the bucket exists and also if we have access to it
      def bucket_exists?
        #will throw an exception if do not have permission to view it...
        !connection.directories.get(bucket).nil?
      rescue Excon::Errors::Forbidden
        raise "An error occurred while trying to access this bucket.  It look like this bucket already exists but does so under a different account which you do not have access to."
      end
      
      ##
      # Creates the bucket.  If the bucket already exists under this key, then the 
      # command doesn't have any impact.  If it exists but under a different owner
      # then an exception is raised
      def create_bucket!
        Logger.message("\"#{ bucket }\" does not exist; creating a private bucket")
        location = region == 'us-east-1' ? nil : region
        connection.directories.create(
          :key    => bucket,
          :public => false,
          :location => location
        )
      rescue Excon::Errors::Forbidden
        raise "An error occurred while trying to create this bucket.  It look like this bucket already exists but does so under a different account which you do not have access to."
      end

      ##
      # Transfers the archived file to the specified Amazon S3 bucket
      def transfer!
        Logger.message("#{ self.class } started transferring \"#{ remote_file }\".")
        connection.sync_clock
        connection.put_object(
          bucket,
          File.join(remote_path, remote_file),
          File.open(File.join(local_path, local_file))
        )
      rescue Excon::Errors::Forbidden
        raise "An error occurred while trying to access this bucket.  It look like this bucket exists under a different account which you do not have access to."
      end

      ##
      # Removes the transferred archive file from the Amazon S3 bucket
      def remove!
        begin
          connection.sync_clock
          connection.delete_object(bucket, File.join(remote_path, remote_file))
        rescue Excon::Errors::SocketError; end
      end

    end
  end
end
