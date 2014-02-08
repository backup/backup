# encoding: utf-8

module Backup
  module Configuration
    module Database
      class OpenLDAP < Base
        class << self

          ##
          # Name of the backup file
          attr_accessor :name

          ##
          # Additional "slapcat" options
          attr_accessor :additional_options

          ##
          # Path to the slapcat utility (optional)
          attr_accessor :slapcat_utility

        end
      end
    end
  end
end
