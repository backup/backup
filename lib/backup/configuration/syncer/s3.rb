# encoding: utf-8

module Backup
  module Configuration
    module Syncer
      class S3 < Cloud
        class << self
          ##
          # Amazon Simple Storage Service (S3) Credentials
          attr_accessor :access_key_id, :secret_access_key, :region
        end
      end
    end
  end
end
