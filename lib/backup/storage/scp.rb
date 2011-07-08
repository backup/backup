# encoding: utf-8

##
# Only load the Net::SSH and Net::SCP library/gems
# when the Backup::Storage::SCP class is loaded
Backup::Dependency.load('net-ssh')
Backup::Dependency.load('net-scp')


module Backup
  module Storage
    class SCP < Base

      ##
      # Server credentials
      attr_accessor :username, :password

      ##
      # Server IP Address and SCP port
      attr_accessor :ip, :port

      ##
      # Path to store backups to
      attr_accessor :path

      ##
      # Creates a new instance of the SCP storage object
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
      # Establishes a connection to the remote server and returns the Net::SSH object.
      # Not doing any instance variable caching because this object gets persisted in YAML
      # format to a file and will issues. This, however has no impact on performance since it only
      # gets invoked once per object for a #transfer! and once for a remove! Backups run in the
      # background anyway so even if it were a bit slower it shouldn't matter.
      #
      # We will be using Net::SSH, and use Net::SCP through Net::SSH to transfer backups
      def connection
        Net::SSH.start(ip, username, :password => password, :port => port)
      end

      ##
      # Transfers the archived file to the specified remote server
      def transfer!
        Logger.message("#{ self.class } started transferring \"#{ remote_file }\".")
        create_remote_directories!
        connection.scp.upload!(
          File.join(local_path, local_file),
          File.join(remote_path, remote_file)
        )
      end

      ##
      # Removes the transferred archive file from the server
      def remove!
        response = connection.exec!("rm #{ File.join(remote_path, remote_file) }")
        if response =~ /No such file or directory/
          Logger.warn "Could not remove file \"#{ File.join(remote_path, remote_file) }\"."
        end
      end

      ##
      # Creates (if they don't exist yet) all the directories on the remote
      # server in order to upload the backup file. Net::SCP does not support
      # paths to directories that don't yet exist when creating new directories.
      # Instead, we split the parts up in to an array (for each '/') and loop through
      # that to create the directories one by one. Net::SCP raises an exception when
      # the directory it's trying ot create already exists, so we have rescue it
      def create_remote_directories!
        path_parts = Array.new
        remote_path.split('/').each do |path_part|
          path_parts << path_part
          connection.exec!("mkdir '#{ path_parts.join('/') }'")
        end
      end

    end
  end
end
