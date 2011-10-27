# encoding: utf-8

module Backup
  module Database
    class Base
      include Backup::CLI
      include Backup::Configuration::Helpers

      ##
      # Contains the path to where the database should be dumped
      attr_accessor :dump_path

      ##
      # Allows the user to specify the path to a "dump" utility
      # in case it cannot be auto-detected by Backup
      attr_accessor :utility_path

      ##
      # Super method for all child (database) objects. Every database object's #perform!
      # method should call #super before anything else to prepare
      def perform!
        prepare!
        log!
      end

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
