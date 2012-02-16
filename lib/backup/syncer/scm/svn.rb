# encoding: utf-8

module Backup
  module Syncer
    module SCM
      class SVN < Base

        def initialize(&block)

          super

          @protocol ||= "http"

          instance_eval(&block) if block_given?
        end

        def local_repository_exists?(repository)
          run "svnadmin verify #{repository_local_path(repository)}"
          return true
        rescue Errors::CLI::SystemCallError
          return false
        end

        def initialize_repository!(repository)
          local_path    = repository_local_path(repository)
          absolute_path = repository_absolute_local_path(repository)
          url           = repository_url(repository)
          hook_path     = File.join(local_path, 'hooks', 'pre-revprop-change')

          Logger.message("Initializing empty svn repository in '#{local_path}'.")

          create_repository_local_container!(repository)

          run "svnadmin create '#{local_path}'"
          run "echo '#!/bin/sh' > '#{hook_path}'"
          run "chmod +x '#{hook_path}'"
          run "svnsync init file://#{absolute_path} #{url}"
        end

        def update_repository!(repository)
          absolute_path = repository_absolute_local_path(repository)
          local_path    = repository_local_path(repository)

          Logger.message("Updating svn repository in '#{local_path}'.")
          run("svnsync sync file://#{absolute_path} --non-interactive")
        end


        def backup_repository!(repository)
          initialize_repository!(repository) unless local_repository_exists?(repository)
          update_repository!(repository)
        end
      end
    end
  end
end
