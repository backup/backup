# encoding: utf-8
require 'net/sftp'

module Backup
  module Storage
    class SFTP < Base

      ##
      # Server credentials
      attr_accessor :username, :password, :ssh_options

      ##
      # Server IP Address and SFTP port
      attr_accessor :ip, :port

      def initialize(model, storage_id = nil)
        super

        @ssh_options ||= {}
        @port        ||= 22
        @path        ||= 'backups'
        path.sub!(/^~\//, '')
      end

      private

      def connection
        Net::SFTP.start(
          ip, username, { :password => password, :port => port }.merge(ssh_options)
        ) {|sftp| yield sftp }
      end

      def transfer!
        connection do |sftp|
          create_remote_path(sftp)

          package.filenames.each do |filename|
            src = File.join(Config.tmp_path, filename)
            dest = File.join(remote_path, filename)
            Logger.info "Storing '#{ ip }:#{ dest }'..."
            sftp.upload!(src, dest)
          end
        end
      end

      # Called by the Cycler.
      # Any error raised will be logged as a warning.
      def remove!(package)
        Logger.info "Removing backup package dated #{ package.time }..."

        remote_path = remote_path_for(package)
        connection do |sftp|
          package.filenames.each do |filename|
            sftp.remove!(File.join(remote_path, filename))
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
      def create_remote_path(sftp)
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
