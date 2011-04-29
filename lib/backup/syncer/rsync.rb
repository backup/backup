# encoding: utf-8

##
# Require the tempfile Ruby library when Backup::Syncer::RSync is loaded
require 'tempfile'

module Backup
  module Syncer
    class RSync < Base

      ##
      # Server credentials
      attr_accessor :username, :password

      ##
      # Server IP Address and SSH port
      attr_accessor :ip

      ##
      # The SSH port to connect to
      attr_writer :port

      ##
      # Directories to sync
      attr_writer :directories

      ##
      # Path to store the synced files/directories to
      attr_accessor :path

      ##
      # Flag for mirroring the files/directories
      attr_writer :mirror

      ##
      # Flag for compressing (only compresses for the transfer)
      attr_writer :compress

      ##
      # Additional options for the rsync cli
      attr_accessor :additional_options

      ##
      # Instantiates a new RSync Syncer object and sets the default configuration
      # specified in the Backup::Configuration::Syncer::RSync. Then it sets the object
      # defaults if particular properties weren't set. Finally it'll evaluate the users
      # configuration file and overwrite anything that's been defined
      def initialize(&block)
        load_defaults!

        @directories          = Array.new
        @additional_options ||= Array.new
        @path               ||= 'backups'
        @port               ||= 22
        @mirror             ||= false
        @compress           ||= false

        instance_eval(&block) if block_given?
        write_password_file!  unless @password.nil?

        @path = path.sub(/^\~\//, '')
      end

      ##
      # Performs the RSync operation
      # debug options: -vhP
      def perform!
        Logger.message("#{ self.class } started syncing #{ directories }.")
        Logger.silent(
          run("#{ utility(:rsync) } -vhP #{ options } #{ directories } '#{ username }@#{ ip }:#{ path }'")
        )

        remove_password_file! unless @password.nil?
      end

      ##
      # Returns all the specified Rsync options, concatenated, ready for the CLI
      def options
        ([archive, mirror, compress, port, password] + additional_options).compact.join("\s")
      end

      ##
      # Returns Rsync syntax for enabling mirroring
      def mirror
        '--delete' if @mirror
      end

      ##
      # Returns Rsync syntax for compressing the file transfers
      def compress
        '--compress' if @compress
      end

      ##
      # Returns Rsync syntax for invoking "archive" mode
      def archive
        '--archive'
      end

      ##
      # Returns Rsync syntax for defining a port to connect to
      def port
        "--port='#{@port}'"
      end

      ##
      # Returns Rsync syntax for setting a password (via a file)
      def password
        "--password-file='#{@password_file.path}'" if @password
      end

      ##
      # If no block has been provided, it'll return the array of @directories.
      # If a block has been provided, it'll evaluate it and add the defined paths to the @directories
      def directories(&block)
        unless block_given?
          return @directories.map do |directory|
            "'#{directory}'"
          end.join("\s")
        end
        instance_eval(&block)
      end

      ##
      # Adds a path to the @directories array
      def add(path)
        @directories << path
      end

      private

      ##
      # Writes the provided password to a temporary file so that
      # the rsync utility can read the password from this file
      def write_password_file!
        unless @password.nil?
          @password_file = Tempfile.new('backup-rsync-password')
          @password_file.write(@password)
          @password_file.close
        end
      end

      ##
      # Removes the previously created @password_file
      # (temporary file containing the password)
      def remove_password_file!
        @password_file.unlink unless @password.nil?
      end

    end
  end
end
