module Backup
  module Storage
    class ProxmoxBackupServer < Base
      include Utilities::Helpers

      attr_accessor :name
      attr_accessor :namespace
      attr_accessor :backup_id
      attr_accessor :repository
      attr_accessor :password
      attr_accessor :encryption_key
      attr_accessor :encryption_password
      attr_accessor :fingerprint
      attr_accessor :devices

      def initialize(model, storage_id = nil)
        super
      end

      private

      def transfer!
        raise "Please set the repository" if repository.nil?

        Logger.info "Syncing to #{repository}..."
        run(backup_command)
      end

      def backup_command
        @backup_command ||= begin
          cmd = "proxmox-backup-client backup #{name ? name : model.trigger}.pxar:#{Config.tmp_path} "
          cmd << " #{Array(devices).map {|dev| "--include-dev #{dev}"}.join(" ")}".rstrip
          cmd << " --keyfile #{encryption_key}" if !encryption_key.nil?
          cmd << " --ns #{namespace}" if !namespace.nil?
          cmd << " --backup-id #{backup_id}" if !backup_id.nil?
          cmd.rstrip
          "/bin/bash -c '#{environment} #{cmd}'"
        end
      end

      def environment
        @environment ||= begin
          environment = {}
          
          environment["PBS_REPOSITORY"] = repository if !repository.nil?
          environment["PBS_PASSWORD"] = password if !password.nil?
          environment["PBS_ENCRYPTION_PASSWORD"] = encryption_password if !encryption_password.nil?
          environment["PBS_FINGERPRINT"] = fingerprint if !fingerprint.nil?

          environment.map do |key, value|
            "#{key}=#{value}"
          end.join(" ")
        end
      end
    end
  end
end
