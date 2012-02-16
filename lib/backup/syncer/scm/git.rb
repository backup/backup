# encoding: utf-8

module Backup
  module Syncer
    module SCM
      class Git < Base

        attr_accessor :username, :password, :host, :protocol, :port, :repo_path, :path

        def initialize(&block)
          super

          @protocol ||= 'git'

          instance_eval(&block) if block_given?
        end

        def local_repository_exists?(repository)
          local_path = repository_local_path(repository)
          run "cd #{local_path} && git rev-parse --git-dir > /dev/null 2>&1"
          return true
        rescue Errors::CLI::SystemCallError
          Logger.message("#{local_path} is not a repository")
          return false
        end

        def clone_repository!(repository)
          Logger.message("Cloning repository in '#{repository_local_path(repository)}'.")
          create_repository_local_container!(repository)
          run "cd #{repository_local_container_path(repository)} && git clone --bare #{repository_url(repository)}"
        end

        def update_repository!(repository)
          local_path = repository_local_path(repository)
          Logger.message("Updating repository in '#{local_path}'.")
          run "cd #{local_path} && git fetch --all"
        end

        def backup_repository!(repository)
          if local_repository_exists?(repository)
            update_repository!(repository)
          else
            clone_repository!(repository)
          end
        end
      end
    end
  end
end
