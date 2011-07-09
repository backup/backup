# encoding: utf-8

##
# Only load the Net::SFTP library/gem when the Backup::Storage::SFTP class is loaded
Backup::Dependency.load('net-sftp')

module Backup
  module Storage
    class SFTP < Base

      ##
      # Server credentials
      attr_accessor :username, :password

      ##
      # Server IP Address and SFTP port
      attr_accessor :ip, :port

      ##
      # Path to store backups to
      attr_accessor :path

      ##
      # Creates a new instance of the SFTP storage object
      # First it sets the defaults (if any exist) and then evaluates
      # the configuration block which may overwrite these defaults
      def initialize(&block)
        load_defaults!

        @port ||= 22
        @path ||= 'backups'

        instance_eval(&block) if block_given?

        @time = TIME
        @path = path.sub(/^\~\//, '')
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
      # Establishes a connection to the remote server and returns the Net::SFTP object.
      # Not doing any instance variable caching because this object gets persisted in YAML
      # format to a file and will issues. This, however has no impact on performance since it only
      # gets invoked once per object for a #transfer! and once for a remove! Backups run in the
      # background anyway so even if it were a bit slower it shouldn't matter.
      def connection
        Net::SFTP.start(ip, username, :password => password, :port => port)
      end

      ##
      # Transfers the archived file to the specified remote server
      def transfer!
        Logger.message("#{ self.class } started transferring files to #{ ip }")
        create_remote_directories!
        c = conenction
        remote_file_list = remote_files
        local_files.each do |local_file|
          connection.upload!(
            File.join(local_path, local_file),
            File.join(remote_path, remote_file_list.shift)
          )
        end
      end

      ##
      # Removes the transferred archive file from the server
      def remove!
        c = connection
        remote_files.each do |remote_file|
          begin
            c.remove!(
              File.join(remote_path, remote_file)
            )
          rescue Net::SFTP::StatusException
            Logger.warn "Could not remove file \"#{ File.join(remote_path, remote_file) }\"."
          end
        end
      end

      ##
      # Creates (if they don't exist yet) all the directories on the remote
      # server in order to upload the backup file. Net::SFTP does not support
      # paths to directories that don't yet exist when creating new directories.
      # Instead, we split the parts up in to an array (for each '/') and loop through
      # that to create the directories one by one. Net::SFTP raises an exception when
      # the directory it's trying ot create already exists, so we have rescue it
      def create_remote_directories!
        path_parts = Array.new
        remote_path.split('/').each do |path_part|
          path_parts << path_part
          begin
            connection.mkdir!(path_parts.join('/'))
          rescue Net::SFTP::StatusException; end
        end
      end

    end
  end
end
