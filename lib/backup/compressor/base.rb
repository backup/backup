# encoding: utf-8

module Backup
  module Compressor
    class Base
      include Backup::CLI::Helpers
      include Backup::Configuration::Helpers

      def initialize
        load_defaults!
      end

      private

      ##
      # Return the encryptor name, with Backup namespace removed
      def compressor_name
        self.class.to_s.sub('Backup::', '')
      end

      ##
      # Logs a message to the console and log file to inform
      # the client that Backup is using the compressor
      def log!
        Logger.message "Using #{ compressor_name } for compression."
      end
    end
  end
end
