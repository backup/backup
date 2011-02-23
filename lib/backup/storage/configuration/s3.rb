# encoding: utf-8

module Backup
  module Storage
    module Configuration
      class S3 < Base
        class << self

          ##
          # Amazon Simple Storage Service (S3) Credentials
          attr_accessor :access_key_id, :secret_access_key

          ##
          # Amazon S3 bucket name
          attr_accessor :bucket

          ##
          # Region of the specified S3 bucket
          attr_accessor :region

        end
      end
    end
  end
end
