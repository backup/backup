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
      # when a backup process is successful, but has warnings
      attr_accessor :on_warning
      alias :notify_on_warning? :on_warning

      ##
      # When set to true, the user will be notified by email
      # when a backup process raises an exception before finishing
      attr_accessor :on_failure
      alias :notify_on_failure? :on_failure

      ##
      # Called with super(model) from subclasses
      def initialize(model)
        @model = model
        load_defaults!

        @on_success = true if on_success.nil?
        @on_warning = true if on_warning.nil?
        @on_failure = true if on_failure.nil?
      end

      ##
      # Performs the notification
      # Takes a flag to indicate that a failure has occured.
      # (this is only set from Model#perform! in the event of an error)
      # If this is the case it will set the 'action' to :failure.
      # Otherwise, it will set the 'action' to either :success or :warning,
      # depending on whether or not any warnings were sent to the Logger.
      # It will then invoke the notify! method with the 'action',
      # but only if the proper on_success, on_warning or on_failure flag is true.
      def perform!(failure = false)
        @template  = Backup::Template.new({:model => @model})

        action = false
        if failure
          action = :failure if notify_on_failure?
        else
          if notify_on_success? || (notify_on_warning? && Logger.has_warnings?)
            action = Logger.has_warnings? ? :warning : :success
          end
        end

        if action
          log!
          notify!(action)
        end
      end

      private

      ##
      # Return the notifier name, with Backup namespace removed
      def notifier_name
        self.class.to_s.sub('Backup::', '')
      end

      ##
      # Logs a message to the console and log file to inform
      # the client that Backup is notifying about the process
      def log!
        Logger.info "#{ notifier_name } started notifying about the process."
      end

    end
  end
end
