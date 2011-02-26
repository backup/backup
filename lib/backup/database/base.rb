# encoding: utf-8

module Backup
  module Database
    class Base
      include Backup::CLI

      attr_accessor :dump_path

      ##
      # Defines the @dump_path and ensures it exists by creating it
      def prepare!
        @dump_path = File.join(TMP_PATH, TRIGGER, self.class.name.split('::').last)
        mkdir(dump_path)
      end

      ##
      # Logs a message to the console and log file to inform
      # the client that Backup is dumping the database
      def log!
        Logger.message("#{ self.class } started dumping and archiving \"#{ name }\".")
      end
    end
  end
end
