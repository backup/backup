# encoding: utf-8

##
# Require the tempfile Ruby library when Backup::Storage::RSync is loaded
require 'tempfile'

##
# Only load the Net::SSH library when the Backup::Storage::RSync class is loaded
Backup::Dependency.load('net-ssh')

module Backup
  module Storage
    class RSync < Base
      include Backup::CLI::Helpers

      ##
      # Server credentials
      attr_accessor :username, :password

      ##
      # Server IP Address and SSH port
      attr_accessor :ip, :port

      ##
      # Path to store backups to
      attr_accessor :path

      ##
      # Flag to use local backups
      attr_accessor :local

      ##
      # This is the remote path to where the backup files will be stored
      def remote_path
        File.join(path, TRIGGER)
      end

      ##
      # Performs the backup transfer
      def perform!
        super
        write_password_file!
        transfer!
      ensure
        remove_password_file!
      end

    private

      ##
      # Set configuration defaults before evaluating configuration block,
      # after setting defaults from Storage::Base
      def pre_configure
        super
        @port   ||= 22
        @path   ||= 'backups'
        @local  ||= false
      end

      ##
      # Adjust configuration after evaluating configuration block,
      # after adjustments from Storage::Base
      def post_configure
        super
        @path = path.sub(/^\~\//, '')
      end

      ##
      # Establishes a connection to the remote server and returns the Net::SSH object.
      def connection
        Net::SSH.start(ip, username, :password => password, :port => port) do |ssh|
          yield ssh
        end
      end

      ##
      # Transfers the archived file to the specified remote server
      def transfer!
        create_remote_directories!

        Logger.message "#{storage_name} started transferring " +
            "'#{ filename }' to '#{ ip }'."

        if local
          run(
            "#{ utility(:rsync) } '#{ File.join(local_path, filename) }' " +
            "'#{ File.join(remote_path, filename[20..-1]) }'"
          )
        else
          run(
            "#{ utility(:rsync) } #{ rsync_options } #{ rsync_port } " +
            "#{ rsync_password_file } '#{ File.join(local_path, filename) }' " +
            "'#{ username }@#{ ip }:#{ File.join(remote_path, filename[20..-1]) }'"
          )
        end
      end

      ##
      # Note: RSync::Storage doesn't cycle
      def remove!
        nil
      end

      ##
      # Creates (if they don't exist yet) all the directories on the remote
      # server in order to upload the backup file.
      def create_remote_directories!
        if @local
          mkdir(remote_path)
        else
          connection do |ssh|
            ssh.exec!("mkdir -p '#{ remote_path }'")
          end
        end
      end

      ##
      # Writes the provided password to a temporary file so that
      # the rsync utility can read the password from this file
      def write_password_file!
        unless password.nil?
          @password_file = Tempfile.new('backup-rsync-password')
          @password_file.write(password)
          @password_file.close
        end
      end

      ##
      # Removes the previously created @password_file
      # (temporary file containing the password)
      def remove_password_file!
        @password_file.delete if @password_file
      end

      ##
      # Returns Rsync syntax for using a password file
      def rsync_password_file
        "--password-file='#{@password_file.path}'" if @password_file
      end

      ##
      # Returns Rsync syntax for defining a port to connect to
      def rsync_port
        "-e 'ssh -p #{port}'"
      end

      ##
      # RSync options
      # -z = Compresses the bytes that will be transferred to reduce bandwidth usage
      def rsync_options
        "-z"
      end

    end
  end
end
