# encoding: utf-8

module Backup
  module Configuration
    class S3 < Base
      class << self
        attr_accessor :access_key_id, :secret_access_key, :region, :bucket
      end

      ##
      # Sets the default Amazon S3 configuration to make
      # larger configuration sets less verbose
      #
      # By setting the configurations here, they will become the default
      # througout the backup process. These defaults can be (individually)
      # overwritten by the Backup::Model
      def self.defaults
        yield self
      end
    end
  end
end
