# encoding: utf-8

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
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil, &block)
        super(model, storage_id)

        @port ||= 22
        @path ||= 'backups'

        instance_eval(&block) if block_given?

        @path = path.sub(/^\~\//, '')
      end

      private

      ##
      # Establishes a connection to the remote server
      def connection
        Net::SFTP.start(
          ip, username,
          :password => password,
          :port     => port
        ) {|sftp| yield sftp }
      end

      ##
      # Transfers the archived file to the specified remote server
      def transfer!
        remote_path = remote_path_for(@package)

        connection do |sftp|
          create_remote_path(remote_path, sftp)

          files_to_transfer_for(@package) do |local_file, remote_file|
            Logger.info "#{storage_name} started transferring " +
                "'#{ local_file }' to '#{ ip }'."

            sftp.upload!(
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

        connection do |sftp|
          transferred_files_for(package) do |local_file, remote_file|
            Logger.info "#{storage_name} started removing " +
                "'#{ local_file }' from '#{ ip }'."

            sftp.remove!(File.join(remote_path, remote_file))
          end

          sftp.rmdir!(remote_path)
        end
      end

      ##
      # Creates (if they don't exist yet) all the directories on the remote
      # server in order to upload the backup file. Net::SFTP does not support
      # paths to directories that don't yet exist when creating new
      # directories. Instead, we split the parts up in to an array (for each
      # '/') and loop through that to create the directories one by one.
      # Net::SFTP raises an exception when the directory it's trying to create
      # already exists, so we have rescue it
      def create_remote_path(remote_path, sftp)
        path_parts = Array.new
        remote_path.split('/').each do |path_part|
          path_parts << path_part
          begin
            sftp.mkdir!(path_parts.join('/'))
          rescue Net::SFTP::StatusException; end
        end
      end

    end
  end
end
