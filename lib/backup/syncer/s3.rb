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
      attr_writer :directories

      ##
      # Flag to enable mirroring
      attr_accessor :mirror

      ##
      # Additional options for the s3sync cli
      attr_accessor :additional_options

      ##
      # Instantiates a new S3 Syncer object and sets the default configuration
      # specified in the Backup::Configuration::Syncer::S3.
      # Then it sets the object defaults if particular properties weren't set.
      # Finally it'll evaluate the users configuration file and overwrite
      # anything that's been defined
      def initialize(&block)
        load_defaults!

        @path               ||= 'backups'
        @directories          = Array.new
        @mirror             ||= false
        @additional_options ||= []

        instance_eval(&block) if block_given?
      end

      ##
      # Sets the Amazon S3 credentials for S3Sync, performs the S3Sync
      # operation, then unsets the credentials (back to nil values)
      def perform!
        set_environment_variables!

        @directories.each do |directory|
          Logger.message("#{ syncer_name } started syncing '#{ directory }'.")
          Logger.silent(
            run("#{ utility(:s3sync) } #{ options } " +
                "'#{ File.expand_path(directory) }' '#{ bucket }:#{ dest_path }'")
          )
        end

        unset_environment_variables!
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

      private

      ##
      # Return @path with preceeding '/' slash removed
      def dest_path
        @dest_path ||= @path.sub(/^\//, '')
      end

      ##
      # Returns all the specified S3Sync options,
      # concatenated, ready for the CLI
      def options
        ([verbose_option, recursive_option, mirror_option] +
          additional_options).compact.join("\s")
      end

      ##
      # Returns S3Sync syntax for enabling mirroring
      def mirror_option
        '--delete' if @mirror
      end

      ##
      # Returns S3Sync syntax for syncing recursively
      def recursive_option
        '--recursive'
      end

      ##
      # Returns S3Sync syntax for making output verbose
      def verbose_option
        '--verbose'
      end

      ##
      # In order for S3Sync to know what credentials to use, we have to set the
      # AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables, these
      # evironment variables will be used by S3Sync
      def set_environment_variables!
        ENV['AWS_ACCESS_KEY_ID']     = access_key_id
        ENV['AWS_SECRET_ACCESS_KEY'] = secret_access_key
        ENV['AWS_CALLING_FORMAT']    = 'SUBDOMAIN'
      end

      ##
      # Sets the AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY back to nil
      def unset_environment_variables!
        ENV['AWS_ACCESS_KEY_ID']     = nil
        ENV['AWS_SECRET_ACCESS_KEY'] = nil
        ENV['AWS_CALLING_FORMAT']    = nil
      end

    end
  end
end
