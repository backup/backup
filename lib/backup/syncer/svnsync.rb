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


    end
  end
end
