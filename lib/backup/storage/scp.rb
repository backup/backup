# encoding: utf-8
require 'net/scp'

module Backup
  module Storage
    class SCP < Base
      class Error < Backup::Error; end

      ##
      # Server credentials
      attr_accessor :username, :password, :ssh_options

      ##
      # Server IP Address and SCP port
      attr_accessor :ip, :port

      def initialize(model, storage_id = nil)
        super

        @port ||= 22
        @path ||= 'backups'
        @ssh_options ||= {}
        path.sub!(/^~\//, '')
      end

      private

      def connection
        Net::SSH.start(
          ip, username, { :password => password, :port => port }.merge(ssh_options)
        ) {|ssh| yield ssh }
      end

      def transfer!
        connection do |ssh|
          ssh.exec!("mkdir -p '#{ remote_path }'")

          package.filenames.each do |filename|
            src = File.join(Config.tmp_path, filename)
            dest = File.join(remote_path, filename)
            Logger.info "Storing '#{ ip }:#{ dest }'..."
            ssh.scp.upload!(src, dest)
          end
        end
      end

      # Called by the Cycler.
      # Any error raised will be logged as a warning.
      def remove!(package)
        Logger.info "Removing backup package dated #{ package.time }..."

        errors = []
        connection do |ssh|
          ssh.exec!("rm -r '#{ remote_path_for(package) }'") do |ch, stream, data|
            errors << data if stream == :stderr
          end
        end
        unless errors.empty?
          raise Error, "Net::SSH reported the following errors:\n" +
              errors.join("\n")
        end
      end

    end
  end
end
