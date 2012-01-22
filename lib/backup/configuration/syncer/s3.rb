# encoding: utf-8

module Backup
  module Configuration
    module Syncer
      class S3 < Base
        class << self

          ##
          # Amazon Simple Storage Service (S3) Credentials
          attr_accessor :access_key_id, :secret_access_key

          ##
          # Amazon S3 bucket name and path to sync to
          attr_accessor :bucket, :path

          ##
          # Flag to enable mirroring
          attr_accessor :mirror

          ##
          # Additional options for the s3sync cli
          attr_accessor :additional_options

        end
      end
    end
  end
end
