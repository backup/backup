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
      # Logs info to the console and backup.log
      def log!
        Logger.message("#{self.class.name} started dumping and archiving \"#{name}\".")
      end
    end
  end
end
