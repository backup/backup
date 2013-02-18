# encoding: utf-8

module Backup
  module Compressor
    class Base
      include Backup::Utilities::Helpers
      include Backup::Configuration::Helpers

      ##
      # Yields to the block the compressor command and filename extension.
      def compress_with
        log!
        yield @cmd, @ext
      end

      private

      ##
      # Return the compressor name, with Backup namespace removed
      def compressor_name
        self.class.to_s.sub('Backup::', '')
      end

      ##
      # Logs a message to the console and log file to inform
      # the client that Backup is using the compressor
      def log!
        Logger.info "Using #{ compressor_name } for compression.\n" +
          "  Command: '#{ @cmd }'\n" +
          "  Ext: '#{ @ext }'"
      end

    end
  end
end
