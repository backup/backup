# encoding: utf-8

module Backup
  module Configuration
    class Base
      extend Backup::Configuration::Helpers

      ##
      # Allows for global configuration through block-notation
      def self.defaults
        yield self
      end
    end
  end
end
