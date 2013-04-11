# encoding: utf-8

require 'ostruct'

module Backup
  module Configuration
    class Store < OpenStruct

      ##
      # Returns an Array of all attribute method names
      # that default values were set for.
      def _attributes
        @table.keys
      end

      ##
      # Used only within the specs
      def reset!
        @table.clear
      end

    end
  end
end
