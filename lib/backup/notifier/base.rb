# encoding: utf-8

module Backup
  module Notifier
    class Base
      include Backup::Configuration::Helpers

      ##
      # When set to true, the user will be notified by email
      # when a backup process ends without raising any exceptions
      attr_accessor :on_success
      alias :notify_on_success? :on_success

      ##
      # When set to true, the user will be notified by email
      # when a backup process raises an exception before finishing
      attr_accessor :on_failure
      alias :notify_on_failure? :on_failure

      ##
      # Logs a message to the console and log file to inform
      # the client that Backup is notifying about the process
      def log!
        Logger.message "#{ self.class } started notifying about the process."
      end

    end
  end
end
