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
      # This is the remote path to where the backup files will be stored.
      # Eventhough it says "remote", it's actually the "local" path, but
      # the naming is necessary for compatibility reasons
      def remote_path
        File.join(path, TRIGGER, @time)
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
        @path ||= "#{ENV['HOME']}/backups"
      end

      ##
      # Adjust configuration after evaluating configuration block,
      # after adjustments from Storage::Base
      def post_configure
        super
        @path = File.expand_path(path)
      end

      ##
      # Transfers the archived file to the specified local path
      def transfer!
        create_local_directories!

        files_to_transfer do |local_file, remote_file|
          Logger.message("#{ self.class } started transferring \"#{ local_file }\".")
          FileUtils.cp(
            File.join(local_path, local_file),
            File.join(remote_path, remote_file)
          )
        end
      end

      ##
      # Removes the transferred archive file from the local path
      def remove!
        transferred_files do |local_file, remote_file|
          Logger.message("#{ self.class } started removing \"#{ local_file }\".")
        end

        FileUtils.rm_rf(remote_path)
      end

      ##
      # Creates the path to where the backups are stored if it doesn't exist yet
      def create_local_directories!
        FileUtils.mkdir_p(remote_path)
      end

    end
  end
end
