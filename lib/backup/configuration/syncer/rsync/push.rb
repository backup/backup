# encoding: utf-8

module Backup
  module Configuration
    module Syncer
      module RSync
        class Push < Base
          class << self

            ##
            # Server credentials
            attr_accessor :username, :password

            ##
            # Server IP Address and SSH port
            attr_accessor :ip

            ##
            # The SSH port to connect to
            attr_accessor :port

            ##
            # Flag for compressing (only compresses for the transfer)
            attr_accessor :compress

          end
        end
      end
    end
  end
end
