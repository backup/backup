# encoding: utf-8

module Backup
  module Notifier
    class Base
      include Backup::Configuration::Helpers

      ##
      # Container for the Model object
      attr_accessor :model

      ##
      # Contains the Exception object or False
      attr_accessor :exception

      ##
      # Contains the Backup::Template object
      attr_accessor :template

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
      # Super method #initialize for all child classes
      def initialize(&block)
        load_defaults!

        instance_eval(&block) if block_given?

        set_defaults!
      end

      ##
      # Performs the notification
      # Takes an exception object that might've been created if an exception occurred.
      # If this is the case it'll invoke notify_failure!(exception), otherwise, if no
      # error was raised, it'll go ahead and notify_success!
      #
      # If'll only perform these if on_success is true or on_failure is true
      def perform!(model, exception = false)
        @model     = model
        @exception = exception
        @template  = Backup::Template.new(binding)

        if notify_on_success? and exception.eql?(false)
          log!
          notify_success!
        elsif notify_on_failure? and not exception.eql?(false)
          log!
          notify_failure!
        end
      end

      ##
      # Logs a message to the console and log file to inform
      # the client that Backup is notifying about the process
      def log!
        Logger.message "#{ self.class } started notifying about the process."
      end

    end
  end
end
