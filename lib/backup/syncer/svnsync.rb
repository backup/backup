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

      def local_repo_exists?
        run "svn info #{path}"
        return !self.stderr.end_with?('is not a working copy')
      end

      def initialize_repo
        Logger.message("Initializing repo")
        run "svnadmin create '#{path}'"
        change_path = File.join(path, 'hooks', 'pre-revprop-change')
        run "echo '#!/bin/sh' > '#{change_path}'"
        run "chmod +x '#{change_path}'"
        run "svnsync init file://#{path} #{url} --source-username #{username} --source-password #{password}"
      end

      def perform!
        Logger.message("#{ self.class } started syncing '#{ url }' '#{ path }'.")
        mkdir(path)
        initialize_repo unless local_repo_exists?
        run "svnsync sync file://#{path} --source-username #{username} --source-password #{password} --non-interactive"
      end


    end
  end
end
