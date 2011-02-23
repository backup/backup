# encoding: utf-8

##
# Only load the Fog gem when the Backup::Storage::S3 class is loaded
require 'fog'

module Backup
  module Storage
    class S3 < Base

      ##
      # Amazon Simple Storage Service (S3) Credentials
      attr_accessor :access_key_id, :secret_access_key

      ##
      # Amazon S3 bucket name
      attr_accessor :bucket

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
        %w[access_key_id secret_access_key bucket region].each do |attribute|
          self.send("#{attribute}=", Backup::Configuration::S3.send(attribute))
        end

        instance_eval(&block) if block_given?
        @time = TIME
      end

      ##
      # This is the provider that Fog uses for the S3 Storage
      def provider
        'AWS'
      end

      ##
      # Performs the backup transfer
      def perform!
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
      # Transfers the archived file to the specified Amazon S3 bucket
      def transfer!
        begin
          connection.put_object(
            bucket,
            File.join(remote_path, remote_file),
            File.read(File.join(local_path, local_file))
          )
        rescue Excon::Errors::SocketError
          puts "\nAn error occurred while trying to transfer the backup."
          puts "Make sure the bucket exists, and that you specified the correct bucket region.\n\n"
          puts "The available regions are:\n\n"
          puts %w[eu-west-1 us-east-1 ap-southeast-1 us-west-1].map{ |region| "\s\s* #{region}" }.join("\n")
          exit
        end
      end

      ##
      # Removes the transferred archive file from the Amazon S3 bucket
      def remove!
        begin
          connection.delete_object(bucket, File.join(remote_path, remote_file))
        rescue Excon::Errors::SocketError
        end
      end

    end
  end
end
