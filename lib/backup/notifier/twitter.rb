# encoding: utf-8

##
# Only load the Twitter gem when using Twitter notifications
require 'twitter'

module Backup
  module Notifier
    class Twitter < Base

      ##
      # Container for the Twitter Client object
      attr_accessor :twitter_client

      ##
      # Container for the Model object
      attr_accessor :model

      ##
      # Twitter consumer key credentials
      attr_accessor :consumer_key, :consumer_secret

      ##
      # OAuth credentials
      attr_accessor :oauth_token, :oauth_token_secret

      ##
      # Instantiates a new Backup::Notifier::Twitter object
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
      # Sends a tweet informing the user that the backup operation
      # proceeded without any errors
      def notify_success!
        twitter_client.update("[Backup::Succeeded] #{model.label} (#{model.trigger})")
      end

      ##
      # Sends a tweet informing the user that the backup operation
      # raised an exception and will send the user the error details
      def notify_failure!(exception)
        twitter_client.update("[Backup::Failed] #{model.label} (#{model.trigger})")
      end

      ##
      # Configures the Twitter object by passing in the @consumer_key, @consumer_secret
      # @oauth_token and @oauth_token_secret. Instantiates and sets the @twitter_client object
      def set_defaults!
        ::Twitter.configure do |config|
          config.consumer_key       = @consumer_key
          config.consumer_secret    = @consumer_secret
          config.oauth_token        = @oauth_token
          config.oauth_token_secret = @oauth_token_secret
        end
        @twitter_client = ::Twitter.client
      end

    end
  end
end
