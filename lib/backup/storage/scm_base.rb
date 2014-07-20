# encoding: utf-8

module Backup
  module Storage
    class SCMBase < SSHBase

      include Utilities::Helpers

      def initialize model, storage_id = nil
        super
      end

      def transfer!
        connection do |ssh|
          self.init_repo ssh
          self.syncer.perform!
          self.commit ssh
        end
      end

      def syncer
        self.rsync
      end

      protected

      def init_repo ssh
        ssh.exec! "mkdir -p '#{ remote_path }'"
      end
      def commit ssh
        raise 'Not implemented'
      end

      def filenames
        syncer.directories.map{ |d| File.basename d }
      end

      # Reimplement to remove time from path
      def remote_path pkg = package
        path
      end

      def rsync
        unless @rsync
          @rsync = Backup::Syncer::RSync::Push.new
          @rsync.mode = :ssh
          @rsync.mirror = true
          @rsync.host = self.ip
          @rsync.port = self.port
          @rsync.ssh_user = self.username
          @rsync.path = self.remote_path
          @rsync.add File.join(Config.tmp_path, package.trigger)
        end
        @rsync
      end

      # Disable cycling for an obvious reason
      def cycle!
      end

    end
  end
end

