# encoding: utf-8

module Backup
  module Configuration
    module Syncer
      class Cloud < Base
        class << self
          ##
          # Amazon S3 bucket name and path to sync to
          attr_accessor :bucket, :path

          ##
          # Directories to sync
          attr_accessor :directories

          ##
          # Flag to enable mirroring
          attr_accessor :mirror
        end
      end
    end
  end
end
