# encoding: utf-8

##
# Only load the Prowler gem when using Prowler notifications
Backup::Dependency.load('prowler')

module Backup
  module Notifier
    class Prowl < Base

      ##
      # Container for the Twitter Client object
      attr_accessor :prowl_client

      ##
      # Container for the Model object
      attr_accessor :model

      ##
      # Application name
      # Tell something like your server name. Example: "Server1 Backup"
      attr_accessor :application
      
      ##
      # API-Key
      # Create a Prowl account and request an API key on prowlapp.com.
      attr_accessor :api_key

      ##
      # Instantiates a new Backup::Notifier::Prowl object
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
        @model = model

        if notify_on_success? and exception.eql?(false)
          log!
          notify_success!
        elsif notify_on_failure? and not exception.eql?(false)
          log!
          notify_failure!(exception)
        end
      end

    private

      ##
      # Sends a push message informing the user that the backup operation
      # proceeded without any errors
      def notify_success!
        prowl_client.notify("[Backup::Succeeded]", "#{model.label} (#{ File.basename(Backup::Model.file) })")
      end

      ##
      # Sends a push message informing the user that the backup operation
      # raised an exception
      def notify_failure!(exception)
        prowl_client.notify("[Backup::Failed]", "#{model.label} (#{ File.basename(Backup::Model.file) })")
      end

      ##
      # Configures the Prowler object by passing in the @api_key and the
      # @application. Instantiates and sets the @prowl_client object
      def set_defaults!
        @prowl_client = Prowler.new(:application => application, :api_key => api_key)
      end

    end
  end
end
