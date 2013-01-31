# encoding: utf-8

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
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil, &block)
        super(model, storage_id)

        @port   ||= 22
        @path   ||= 'backups'
        @local  ||= false

        instance_eval(&block) if block_given?

        @path = path.sub(/^\~\//, '')
      end

      private

      ##
      # This is the remote path to where the backup files will be stored
      #
      # Note: This overrides the superclass' method
      def remote_path_for(package)
        File.join(path, package.trigger)
      end

      ##
      # Establishes a connection to the remote server
      def connection
        Net::SSH.start(
          ip, username, :password => password, :port => port
        ) {|ssh| yield ssh }
      end

      ##
      # Transfers the archived file to the specified remote server
      def transfer!
        write_password_file! unless local

        remote_path = remote_path_for(@package)

        create_remote_path!(remote_path)

        files_to_transfer_for(@package) do |local_file, remote_file|
          if local
            Logger.info "#{storage_name} started transferring " +
                "'#{ local_file }' to '#{ remote_path }'."
            run(
              "#{ utility(:rsync) } '#{ File.join(local_path, local_file) }' " +
              "'#{ File.join(remote_path, remote_file) }'"
            )
          else
            Logger.info "#{storage_name} started transferring " +
                "'#{ local_file }' to '#{ ip }'."
            run(
              "#{ utility(:rsync) } #{ rsync_options } #{ rsync_port } " +
              "#{ rsync_password_file } '#{ File.join(local_path, local_file) }' " +
              "'#{ username }@#{ ip }:#{ File.join(remote_path, remote_file) }'"
            )
          end
        end

      ensure
        remove_password_file! unless local
      end

      ##
      # Note: Storage::RSync doesn't cycle
      def remove!; end

      ##
      # Creates (if they don't exist yet) all the directories on the remote
      # server in order to upload the backup file.
      def create_remote_path!(remote_path)
        if @local
          FileUtils.mkdir_p(remote_path)
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
        @password_file = nil
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
