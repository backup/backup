# encoding: utf-8

module Backup
  module Configuration
    module Syncer
      module Cloud
        class S3 < Base
          class << self

            ##
            # Amazon Simple Storage Service (S3) Credentials
            attr_accessor :access_key_id, :secret_access_key

            ##
            # The S3 bucket to store files to
            attr_accessor :bucket

            ##
            # The AWS region of the specified S3 bucket
            attr_accessor :region

          end
        end
      end
    end
  end
end
