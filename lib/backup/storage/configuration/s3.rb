# encoding: utf-8

module Backup
  module Storage
    module Configuration
      class S3 < Base
        class << self
          attr_accessor :access_key_id, :secret_access_key, :region, :bucket
        end
      end
    end
  end
end
