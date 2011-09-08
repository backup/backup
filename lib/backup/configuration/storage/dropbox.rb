# encoding: utf-8

module Backup
  module Configuration
    module Storage
      class Dropbox < Base
        class << self

          ##
          # Dropbox API credentials
          attr_accessor :serialized_session

          ##
          # Path to where the backups will be stored
          attr_accessor :path

          ##
          # Dropbox connection timeout
          attr_accessor :timeout

        end
      end
    end
  end
end
