# encoding: utf-8

module Backup
  module Compressor
    class Base
      include Backup::CLI::Helpers
      include Backup::Configuration::Helpers

      ##
      # Logs a message to the console and log file to inform
      # the client that Backup is compressing the archive
      def log!
        Logger.message "#{ self.class } started compressing the archive."
      end
    end
  end
end
