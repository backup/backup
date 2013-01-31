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
      # and yields the Net::SSH connection.
      # Net::SCP will use this connection to transfer backups
      def connection
        Net::SSH.start(
          ip, username, :password => password, :port => port
        ) {|ssh| yield ssh }
      end

      ##
      # Transfers the archived file to the specified remote server
      def transfer!
        remote_path = remote_path_for(@package)

        connection do |ssh|
          ssh.exec!("mkdir -p '#{ remote_path }'")

          files_to_transfer_for(@package) do |local_file, remote_file|
            Logger.info "#{storage_name} started transferring " +
                "'#{local_file}' to '#{ip}'."

            ssh.scp.upload!(
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

        messages = []
        transferred_files_for(package) do |local_file, remote_file|
          messages << "#{storage_name} started removing " +
              "'#{local_file}' from '#{ip}'."
        end
        Logger.info messages.join("\n")

        errors = []
        connection do |ssh|
          ssh.exec!("rm -r '#{remote_path}'") do |ch, stream, data|
            errors << data if stream == :stderr
          end
        end
        unless errors.empty?
          raise Errors::Storage::SCP::SSHError,
            "Net::SSH reported the following errors:\n" +
              errors.join("\n")
        end
      end

    end
  end
end
