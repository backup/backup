# encoding: utf-8

##
# Load the Ruby FileUtils library
require 'fileutils'

module Backup
  module Storage
    class Local < Base

      ##
      # Path to store backups to
      attr_accessor :path

      ##
      # Creates a new instance of the Local storage object
      # First it sets the defaults (if any exist) and then evaluates
      # the configuration block which may overwrite these defaults
      def initialize(&block)
        load_defaults!

        @path ||= "#{ENV['HOME']}/backups"

        instance_eval(&block) if block_given?

        @time = TIME
        fix_path!
      end

      ##
      # This is the remote path to where the backup files will be stored.
      # Eventhough it says "remote", it's actually the "local" path, but
      # the naming is necessary for compatibility reasons
      def remote_path
        File.join(path, TRIGGER)
      end

      ##
      # Performs the backup transfer
      def perform!
        transfer!
        cycle!
      end

    private

      ##
      # Transfers the archived file to the specified local path
      def transfer!
        Logger.message("#{ self.class } started transferring \"#{ remote_file }\".")
        create_local_directories!
        FileUtils.cp(
          File.join(local_path, local_file),
          File.join(remote_path, remote_file)
        )
      end

      ##
      # Removes the transferred archive file from the local path
      def remove!
        FileUtils.rm(File.join(remote_path, remote_file))
      end

      ##
      # Creates the path to where the backups are stored if it doesn't exist yet
      def create_local_directories!
        FileUtils.mkdir_p(remote_path)
      end

      ##
      # Replaces ~/ with the full path to the users $HOME directory
      def fix_path!
        @path = path.sub(/^\~\//, "#{ENV['HOME']}/")
      end

    end
  end
end
