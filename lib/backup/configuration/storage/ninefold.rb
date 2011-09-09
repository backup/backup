# encoding: utf-8

module Backup
  module Configuration
    module Storage
      class Ninefold < Base
        class << self

          ##
          # Ninefold Credentials
          attr_accessor :storage_token, :storage_secret

          ##
          # Ninefold path
          attr_accessor :path
        end
      end
    end
  end
end
