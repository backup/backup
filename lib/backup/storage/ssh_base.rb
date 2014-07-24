# encoding: utf-8
require 'net/ssh'

module Backup
  module Storage
    class SSHBase < Base
      class Error < Backup::Error; end

      ##
      # Server credentials
      attr_accessor :username, :password, :ssh_options

      ##
      # Server IP Address and SFTP port
      attr_accessor :ip, :port
      alias :host :ip
      alias :host= :ip=

      def initialize model, storage_id = nil
        super

        @port ||= 22
        @path ||= 'backups'
        @ssh_options ||= {}
        path.sub!(/^~\//, '')
      end

      protected

      def connection
        Net::SSH.start(
          ip, username, { :password => password, :port => port }.merge(ssh_options)
        ) {|ssh| yield ssh }
      end

    end
  end
end
