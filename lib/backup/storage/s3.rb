# encoding: utf-8

##
# Only load the Fog gem when the
# Backup::Storage::S3 class is loaded
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
      # Determines whether a connection has been establised to Amazon S3
      attr_accessor :connected
      alias :connected? :connected

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

        instance_eval(&block)
        @connected   = false
        @transferred = false
        @time        = TIME
      end

      ##
      # This is the provider that Fog uses for the S3 Storage
      def provider
        'AWS'
      end

      ##
      # Establishes a connection to Amazon S3 and returns the Fog object
      def connection
        return @connection if connected?
        @connected  = true
        @connection = Fog::Storage.new(
          :provider               => provider,
          :aws_access_key_id      => access_key_id,
          :aws_secret_access_key  => secret_access_key,
          :region                 => region
        )
      end

      ##
      # Transfers the archived file to the specified Amazon S3 bucket
      def transfer!
        connection.put_object(bucket, File.join(remote_path, remote_file), file)
        @transferred = true
      end

      ##
      # Removes the transferred archive file from the Amazon S3 bucket
      def remove!
        begin
          connection.delete_object(bucket, File.join(remote_path, remote_file))
        rescue Excon::Errors::SocketError
        end
      end

      ##
      # Creates the bucket if it doesn't exist
      def create_bucket!
        connection.put_bucket(bucket)
      end

      ##
      # Performs the backup transfer
      def perform!
        create_bucket!
        transfer!
      end

    end
  end
end
