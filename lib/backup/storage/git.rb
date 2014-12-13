# encoding: utf-8

module Backup
  module Storage
    class Git < SCMBase

      protected

      def init_repo(ssh)
        super
        ssh.exec! "#{cmd} config --global user.name 'backup'"
        ssh.exec! "#{cmd} config --global user.email 'backup@#{Config.hostname}'"
        ssh.exec! "#{cmd} init"
      end

      def commit(ssh)
        filenames.each do |dir|
          ssh.exec! "#{self.cmd} add #{dir}"
        end
        ssh.exec! "#{cmd} commit -m 'backup #{self.package.time}'"
      end

      def cmd
        "cd '#{remote_path}' && #{utility :git}"
      end

      def excludes
        ['.git']
      end
    end
  end
end

