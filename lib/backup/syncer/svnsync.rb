# encoding: utf-8

module Backup
  module Syncer
    class SVNSync < Base

      attr_accessor :protocol, :username, :password, :host, :port, :repo_path, :path, :options

      def initialize(&block)

        load_defaults!

        @protocol ||= "http"
        @port ||= "80"

        instance_eval(&block) if block_given?
      end

      def url
        "#{protocol}://#{host}:#{port}#{repo_path}"
      end

      def local_repository_exists?
        run "svnadmin verify #{path}"
        return true
      rescue Errors::CLI::SystemCallError
        Logger.message("#{path} is not a repository")
        return false
      end

      def initialize_repository
        Logger.message("Initializing empty repository")
        run "svnadmin create '#{path}'"
        hook_path = File.join(path, 'hooks', 'pre-revprop-change')
        run "echo '#!/bin/sh' > '#{hook_path}'"
        run "chmod +x '#{hook_path}'"
        run "svnsync init file://#{path} #{url} #{options}"
      end

      def perform!
        Logger.message("#{ self.class } started syncing '#{ url }'.")
        FileUtils.mkdir_p(path)
        initialize_repository unless local_repository_exists?
        Logger.message("Syncing with remote repository")
        run "svnsync sync file://#{path} --non-interactive #{options}"
      end
      
      def options
        ([remote_repository_username, remote_repository_password]).compact.join("\s")
      end
      
      def remote_repository_username
        return "--source-username #{username}" if self.username
      end
      
      def remote_repository_password
        return "--source-password #{password}" if self.password
      end

    end
  end
end
