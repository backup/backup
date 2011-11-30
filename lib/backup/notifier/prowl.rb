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
      # Application name
      # Tell something like your server name. Example: "Server1 Backup"
      attr_accessor :application

      ##
      # API-Key
      # Create a Prowl account and request an API key on prowlapp.com.
      attr_accessor :api_key

      ##
      # Performs the notification
      # Extends from super class. Must call super(model, exception).
      # If any pre-configuration needs to be done, put it above the super(model, exception)
      def perform!(model, exception = false)
        super(model, exception)
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
