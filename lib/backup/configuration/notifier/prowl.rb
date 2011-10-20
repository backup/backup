# encoding: utf-8

module Backup
  module Configuration
    module Notifier
      class Prowl < Base
        class << self

          ##
          # Application name
          # Tell something like your server name. Example: "Server1 Backup"
          attr_accessor :application

          ##
          # API-Key
          # Create a Prowl account and request an API key on prowlapp.com.
          attr_accessor :api_key

        end
      end
    end
  end
end
