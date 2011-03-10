# encoding: utf-8

module Backup
  module Configuration
    module Storage
      class SFTP < Base
        class << self

          ##
          # Server credentials
          attr_accessor :username, :password

          ##
          # Server IP Address and SFTP port
          attr_accessor :ip, :port

          ##
          # Path to store backups to
          attr_accessor :path

        end
      end
    end
  end
end
