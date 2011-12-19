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
      # This is the remote path to where the backup files will be stored
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
        @port ||= 22
        @path ||= 'backups'
      end

      ##
      # Adjust configuration after evaluating configuration block,
      # after adjustments from Storage::Base
      def post_configure
        super
        @path = path.sub(/^\~\//, '')
      end

      ##
      # Establishes a connection to the remote server and returns the Net::SFTP object.
      # Not doing any instance variable caching because this object gets persisted in YAML
      # format to a file and will issues. This, however has no impact on performance since it only
      # gets invoked once per object for a #transfer! and once for a remove! Backups run in the
      # background anyway so even if it were a bit slower it shouldn't matter.
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
        connection do |sftp|
          create_remote_directories(sftp)

          files_to_transfer do |local_file, remote_file|
            Logger.message "#{storage_name} started transferring " +
                "'#{ local_file }' to '#{ ip }'."

            sftp.upload!(
              File.join(local_path, local_file),
              File.join(remote_path, remote_file)
            )
          end
        end
      end

      ##
      # Removes the transferred archive file from the server
      def remove!
        connection do |sftp|
          transferred_files do |local_file, remote_file|
            Logger.message "#{storage_name} started removing " +
                "'#{ local_file }' from '#{ ip }'."

            sftp.remove!(File.join(remote_path, remote_file))
          end

          sftp.rmdir!(remote_path)
        end
      end

      ##
      # Creates (if they don't exist yet) all the directories on the remote
      # server in order to upload the backup file. Net::SFTP does not support
      # paths to directories that don't yet exist when creating new directories.
      # Instead, we split the parts up in to an array (for each '/') and loop through
      # that to create the directories one by one. Net::SFTP raises an exception when
      # the directory it's trying to create already exists, so we have rescue it
      def create_remote_directories(sftp)
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
