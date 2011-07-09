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
      include Backup::CLI

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
      # Creates a new instance of the RSync storage object
      # First it sets the defaults (if any exist) and then evaluates
      # the configuration block which may overwrite these defaults
      def initialize(&block)
        load_defaults!

        @port ||= 22
        @path ||= 'backups'

        instance_eval(&block) if block_given?
        write_password_file!

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
        remove_password_file!
      end

    private

      ##
      # Establishes a connection to the remote server and returns the Net::SSH object.
      # Not doing any instance variable caching because this object gets persisted in YAML
      # format to a file and will issues. This, however has no impact on performance since it only
      # gets invoked once per object for a #transfer! and once for a remove! Backups run in the
      # background anyway so even if it were a bit slower it shouldn't matter.
      def connection
        Net::SSH.start(ip, username, :password => @password, :port => port)
      end

      ##
      # Transfers the archived file to the specified remote server
      def transfer!
        Logger.message("#{ self.class } started transferring files with rsync.")
        create_remote_directories!
        remote_file_list = remote_files
        local_files.each do |local_file|
          run("#{ utility(:rsync) } #{ options } #{ password } '#{ File.join(local_path, local_file) }' '#{ username }@#{ ip }:#{ File.join(remote_path, remote_file_list.shift) }'")
        end
      end

      ##
      # Removes the transferred archive file from the server
      def remove!
        create_remote_directories
        c = connection
        remote_files.each do |remote_file|
          c.exec!("rm #{ File.join(remote_path, remote_file) }")
          if response =~ /No such file or directory/
            Logger.warn "Could not remove file \"#{ File.join(remote_path, remote_file) }\"."
          end
        end
      end

      ##
      # Creates (if they don't exist yet) all the directories on the remote
      # server in order to upload the backup file.
      def create_remote_directories!
        connection.exec!("mkdir -p '#{ remote_path }'")
      end

      ##
      # RSync options
      # -z     = Compresses the bytes that will be transferred to reduce bandwidth usage
      # --port = the port to connect to through SSH
      # -Phv   = debug options
      def options
        "-z --port='#{ port }'"
      end

      ##
      # Returns Rsync syntax for using a password file
      def password
        "--password-file='#{@password_file.path}'" unless @password.nil?
      end

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
