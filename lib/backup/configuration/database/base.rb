# encoding: utf-8

module Backup
  module Configuration
    module Database
      class Base < Configuration::Base
        class << self

          ##
          # Allows the user to specify the path to a "dump" utility
          # in case it cannot be auto-detected by Backup
          # [DEPRECATED] - use <utility_name>_utility methods
          attr_accessor :utility_path

        end
      end
    end
  end
end
