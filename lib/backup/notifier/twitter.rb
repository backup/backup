# encoding: utf-8
require 'twitter'

module Backup
  module Notifier
    class Twitter < Base

      ##
      # Twitter consumer key credentials
      attr_accessor :consumer_key, :consumer_secret

      ##
      # OAuth credentials
      attr_accessor :oauth_token, :oauth_token_secret

      def initialize(model, &block)
        super
        instance_eval(&block) if block_given?
      end

      private

      ##
      # Notify the user of the backup operation results.
      #
      # `status` indicates one of the following:
      #
      # `:success`
      # : The backup completed successfully.
      # : Notification will be sent if `on_success` is `true`.
      #
      # `:warning`
      # : The backup completed successfully, but warnings were logged.
      # : Notification will be sent if `on_warning` or `on_success` is `true`.
      #
      # `:failure`
      # : The backup operation failed.
      # : Notification will be sent if `on_warning` or `on_success` is `true`.
      #
      def notify!(status)
        send_message(message.call(model, :status => status_data_for(status)))
      end

      # Twitter::Client will raise an error if unsuccessful.
      def send_message(message)
        client = ::Twitter::REST::Client.new do |config|
          config.consumer_key        = @consumer_key
          config.consumer_secret     = @consumer_secret
          config.access_token        = @oauth_token
          config.access_token_secret = @oauth_token_secret
        end

        client.update(message)
      end

    end
  end
end
