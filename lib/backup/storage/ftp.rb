# encoding: utf-8

##
# Only load the Net::FTP library/gem when the Backup::Storage::FTP class is loaded
require 'net/ftp'

module Backup
  module Storage
    class FTP < Base

      ##
      # Server credentials
      attr_accessor :username, :password

      ##
      # Server IP Address and FTP port
      attr_accessor :ip, :port

      ##
      # Path to store backups to
      attr_accessor :path

      ##
      # Creates a new instance of the FTP storage object
      # First it sets the defaults (if any exist) and then evaluates
      # the configuration block which may overwrite these defaults
      def initialize(&block)
        load_defaults!
        instance_eval(&block) if block_given?
        @time = TIME
      end

      ##
      # This is the remote path to where the backup files will be stored
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
      # Establishes a connection to the remote server and returns the Net::FTP object.
      # Not doing any instance variable caching because this object gets persisted in YAML
      # format to a file and will issues. This, however has no impact on performance since it only
      # gets invoked once per object for a #transfer! and once for a remove! Backups run in the
      # background anyway so even if it were a bit slower it shouldn't matter.
      #
      # Note *
      # Since the FTP port is defined as a constant in the Net::FTP class, and might be required
      # to change by the user, we dynamically remove and re-add the constant with the provided port value
      def connection
        if defined? Net::FTP::FTP_PORT
          Net::FTP.send(:remove_const, :FTP_PORT)
        end; Net::FTP.send(:const_set, :FTP_PORT, port)

        Net::FTP.new(ip, username, password)
      end

      ##
      # Transfers the archived file to the specified remote server
      def transfer!
        Logger.message("#{ self.class } started transferring \"#{ remote_file }\".")
        create_remote_directories!
        connection.put(
          File.join(local_path, local_file),
          File.join(remote_path, remote_file)
        )
      end

      ##
      # Removes the transferred archive file from the server
      def remove!
        connection.delete(
          File.join(remote_path, remote_file)
        )
      end

      ##
      # Creates (if they don't exist yet) all the directories on the remote
      # server in order to upload the backup file. Net::FTP does not support
      # paths to directories that don't yet exist when creating new directories.
      # Instead, we split the parts up in to an array (for each '/') and loop through
      # that to create the directories one by one. Net::FTP raises an exception when
      # the directory it's trying ot create already exists, so we have rescue it
      def create_remote_directories!
        path_parts = Array.new
        remote_path.split('/').each do |path_part|
          path_parts << path_part
          begin
            connection.mkdir(path_parts.join('/'))
          rescue Net::FTPPermError
          end
        end
      end

    end
  end
end
