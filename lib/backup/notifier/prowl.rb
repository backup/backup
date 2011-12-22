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
      # Notify the user of the backup operation results.
      # `status` indicates one of the following:
      #
      # `:success`
      # : The backup completed successfully.
      # : Notification will be sent if `on_success` was set to `true`
      #
      # `:warning`
      # : The backup completed successfully, but warnings were logged
      # : Notification will be sent, including a copy of the current
      # : backup log, if `on_warning` was set to `true`
      #
      # `:failure`
      # : The backup operation failed.
      # : Notification will be sent, including the Exception which caused
      # : the failure, the Exception's backtrace, a copy of the current
      # : backup log and other information if `on_failure` was set to `true`
      #
      def notify!(status)
        name = case status
               when :success then 'Success'
               when :warning then 'Warning'
               when :failure then 'Failure'
               end
        message = '[Backup::%s]' % name
        prowl_client.notify(message, "#{model.label} (#{model.trigger})")
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
