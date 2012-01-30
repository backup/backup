# encoding: utf-8

module Backup
  module Configuration
    module Syncer
      class Rackspace < Cloud
        class << self
          ##
          # Rackspace CloudFiles Credentials
          attr_accessor :api_key, :username, :auth_url
        end
      end
    end
  end
end
