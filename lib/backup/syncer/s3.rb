# encoding: utf-8

module Backup
  module Syncer
    class S3 < Base

      ##
      # Amazon Simple Storage Service (S3) Credentials
      attr_accessor :access_key_id, :secret_access_key

      ##
      # Amazon S3 bucket name and path to sync to
      attr_accessor :bucket, :path

      ##
      # Directories to sync
      attr_accessor :directories

      ##
      # Flag to enable mirroring
      attr_accessor :mirror

      ##
      # Additional options for the s3sync cli
      attr_accessor :additional_options

      ##
      # Instantiates a new S3 Syncer object and sets the default configuration
      # specified in the Backup::Configuration::Syncer::S3. Then it sets the object
      # defaults if particular properties weren't set. Finally it'll evaluate the users
      # configuration file and overwrite anything that's been defined
      def initialize(&block)
        load_defaults!

        @path               ||= 'backups'
        @directories        ||= Array.new
        @mirror             ||= false
        @additional_options ||= []

        instance_eval(&block) if block_given?

        @path = path.sub(/^\//, '')
      end

      ##
      # Performs the S3Sync operation
      # First it'll set the Amazon S3 credentials for S3Sync before invoking it,
      # and once it's finished syncing the files and directories to Amazon S3, it'll
      # unset these credentials (back to nil values)
      def perform!
        set_s3sync_credentials!

        directories.each do |directory|
          Logger.message("#{ self.class } started syncing '#{ directory }'.")
          Logger.silent( run("#{ utility(:s3sync) } #{ options } '#{ directory }' '#{ bucket }:#{ path }'") )
        end

        unset_s3sync_credentials!
      end

      ##
      # Returns all the specified S3Sync options, concatenated, ready for the CLI
      def options
        ([verbose, recursive, mirror] + additional_options).compact.join("\s")
      end

      ##
      # Returns S3Sync syntax for enabling mirroring
      def mirror
        '--delete' if @mirror
      end

      ##
      # Returns S3Sync syntax for syncing recursively
      def recursive
        '--recursive'
      end

      ##
      # Returns S3Sync syntax for making output verbose
      def verbose
        '--verbose'
      end

      ##
      # Syntactical suger for the DSL for adding directories
      def directories(&block)
        return @directories unless block_given?
        instance_eval(&block)
      end

      ##
      # Adds a path to the @directories array
      def add(path)
        @directories << path
      end

      ##
      # In order for S3Sync to know what credentials to use, we have to set the
      # AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables, these
      # evironment variables will be used by S3Sync
      def set_s3sync_credentials!
        ENV['AWS_ACCESS_KEY_ID']     = access_key_id
        ENV['AWS_SECRET_ACCESS_KEY'] = secret_access_key
      end

      ##
      # Sets the AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY back to nil
      def unset_s3sync_credentials!
        ENV['AWS_ACCESS_KEY_ID']     = nil
        ENV['AWS_SECRET_ACCESS_KEY'] = nil
      end

    end
  end
end
