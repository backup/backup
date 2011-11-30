# encoding: utf-8

##
# Only load the Twitter gem when using Twitter notifications
Backup::Dependency.load('twitter')

module Backup
  module Notifier
    class Twitter < Base

      ##
      # Container for the Twitter Client object
      attr_accessor :twitter_client

      ##
      # Twitter consumer key credentials
      attr_accessor :consumer_key, :consumer_secret

      ##
      # OAuth credentials
      attr_accessor :oauth_token, :oauth_token_secret

      ##
      # Performs the notification
      # Extends from super class. Must call super(model, exception).
      # If any pre-configuration needs to be done, put it above the super(model, exception)
      def perform!(model, exception = false)
        super(model, exception)
      end

    private

      ##
      # Sends a tweet informing the user that the backup operation
      # proceeded without any errors
      def notify_success!
        twitter_client.update("[Backup::Succeeded] #{model.label} (#{ File.basename(Backup::Model.file) })")
      end

      ##
      # Sends a tweet informing the user that the backup operation
      # raised an exception
      def notify_failure!
        twitter_client.update("[Backup::Failed] #{model.label} (#{ File.basename(Backup::Model.file) })")
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
        @twitter_client = ::Twitter::Client.new
      end

    end
  end
end
