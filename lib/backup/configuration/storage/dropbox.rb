# encoding: utf-8

module Backup
  module Configuration
    module Storage
      class Dropbox < Base
        class << self

          ##
          # Dropbox API credentials
          attr_accessor :api_key, :api_secret

          ##
          # Path to where the backups will be stored
          attr_accessor :path

          ##
          # Dropbox connection timeout
          attr_accessor :timeout


          # DEPRECATED METHODS #############################################

          def email
            Logger.warn "[DEPRECATED] Backup::Configuration::Storage::Dropbox.email is deprecated and will be removed at some point."
          end

          def email=(value)
            Logger.warn "[DEPRECATED] Backup::Configuration::Storage::Dropbox.email= is deprecated and will be removed at some point."
          end

          def password
            Logger.warn "[DEPRECATED] Backup::Configuration::Storage::Dropbox.password is deprecated and will be removed at some point."
          end

          def password=(value)
            Logger.warn "[DEPRECATED] Backup::Configuration::Storage::Dropbox.password= is deprecated and will be removed at some point."
          end

        end
      end
    end
  end
end
