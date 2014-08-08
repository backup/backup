# encoding: utf-8

module Backup
  module Storage
    class Hg < SCMBase

      protected

      def init_repo ssh
        super
        ssh.exec! "#{cmd} init"
      end

      def commit ssh
        filenames.each do |dir|
          ssh.exec! "#{self.cmd} add #{dir}"
        end
        ssh.exec! "#{cmd} --config ui.username=backup commit -m 'backup #{package.time}'"
      end

      def cmd
        "cd '#{remote_path}' && #{utility :hg}"
      end

      def excludes
        ['.hg']
      end
    end
  end
end

