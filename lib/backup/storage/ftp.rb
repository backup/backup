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
      # use passive mode?
      attr_accessor :passive_mode

      ##
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil, &block)
        super(model, storage_id)

        @port         ||= 21
        @path         ||= 'backups'
        @passive_mode ||= false

        instance_eval(&block) if block_given?

        @path = path.sub(/^\~\//, '')
      end

      private

      ##
      # Establishes a connection to the remote server
      #
      # Note:
      # Since the FTP port is defined as a constant in the Net::FTP class, and
      # might be required to change by the user, we dynamically remove and
      # re-add the constant with the provided port value
      def connection
        if Net::FTP.const_defined?(:FTP_PORT)
          Net::FTP.send(:remove_const, :FTP_PORT)
        end; Net::FTP.send(:const_set, :FTP_PORT, port)

        Net::FTP.open(ip, username, password) do |ftp|
          ftp.passive = true if passive_mode
          yield ftp
        end
      end

      ##
      # Transfers the archived file to the specified remote server
      def transfer!
        remote_path = remote_path_for(@package)

        connection do |ftp|
          create_remote_path(remote_path, ftp)

          files_to_transfer_for(@package) do |local_file, remote_file|
            Logger.message "#{storage_name} started transferring " +
                "'#{ local_file }' to '#{ ip }'."
            ftp.put(
              File.join(local_path, local_file),
              File.join(remote_path, remote_file)
            )
          end
        end
      end

      ##
      # Removes the transferred archive file(s) from the storage location.
      # Any error raised will be rescued during Cycling
      # and a warning will be logged, containing the error message.
      def remove!(package)
        remote_path = remote_path_for(package)

        connection do |ftp|
          transferred_files_for(package) do |local_file, remote_file|
            Logger.message "#{storage_name} started removing " +
                "'#{ local_file }' from '#{ ip }'."

            ftp.delete(File.join(remote_path, remote_file))
          end

          ftp.rmdir(remote_path)
        end
      end

      ##
      # Creates (if they don't exist yet) all the directories on the remote
      # server in order to upload the backup file. Net::FTP does not support
      # paths to directories that don't yet exist when creating new
      # directories. Instead, we split the parts up in to an array (for each
      # '/') and loop through that to create the directories one by one.
      # Net::FTP raises an exception when the directory it's trying to create
      # already exists, so we have rescue it
      def create_remote_path(remote_path, ftp)
        path_parts = Array.new
        remote_path.split('/').each do |path_part|
          path_parts << path_part
          begin
            ftp.mkdir(path_parts.join('/'))
          rescue Net::FTPPermError; end
        end
      end

    end
  end
end
