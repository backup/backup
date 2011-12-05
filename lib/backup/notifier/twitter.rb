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
        message = "[Backup::%s] #{model.label} (#{model.trigger})" % name
        twitter_client.update(message)
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
