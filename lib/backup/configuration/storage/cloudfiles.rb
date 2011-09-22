# encoding: utf-8

module Backup
  module Configuration
    module Storage
      class CloudFiles < Base
        class << self

          ##
          # Rackspace Cloud Files Credentials
          attr_accessor :api_key, :username, :auth_url

          ##
          # Rackspace Cloud Files container name and path
          attr_accessor :container, :path

        end
      end
    end
  end
end
