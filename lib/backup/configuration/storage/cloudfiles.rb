# encoding: utf-8

module Backup
  module Configuration
    module Storage
      class CloudFiles < Base
        class << self

          ##
          # Rackspace Cloud Files Credentials
          attr_accessor :api_key, :username

          ##
          # Rackspace Cloud Files container name
          attr_accessor :container

        end
      end
    end
  end
end
