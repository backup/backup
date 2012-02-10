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
          # Dropbox Access Type
          # Valid values are:
          #   :app_folder (default)
          #   :dropbox (full access)
          attr_accessor :access_type

          ##
          # Path to where the backups will be stored
          attr_accessor :path


          # DEPRECATED METHODS #############################################

          # Deprecated as of v3.0.21 - for move to official 'dropbox-sdk' gem (v1.1)
          attr_reader :timeout
          def timeout=(value)
            Logger.warn "[DEPRECATED] Backup::Configuration::Storage::Dropbox.timeout=\n" +
                "  is deprecated and will be removed at some point."
          end

          def email
            Logger.warn "[DEPRECATED] Backup::Configuration::Storage::Dropbox.email\n" +
                "  is deprecated and will be removed at some point."
          end

          def email=(value)
            Logger.warn "[DEPRECATED] Backup::Configuration::Storage::Dropbox.email=\n" +
                "  is deprecated and will be removed at some point."
          end

          def password
            Logger.warn "[DEPRECATED] Backup::Configuration::Storage::Dropbox.password\n" +
                "  is deprecated and will be removed at some point."
          end

          def password=(value)
            Logger.warn "[DEPRECATED] Backup::Configuration::Storage::Dropbox.password=\n" +
                "  is deprecated and will be removed at some point."
          end

        end
      end
    end
  end
end
