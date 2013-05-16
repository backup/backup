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
        message = "[Backup::%s] #{@model.label} (#{@model.trigger}) (@ #{@model.time})" % name
        send_message(message)
      end

      def send_message(message)
        ::Twitter.configure do |config|
          config.consumer_key       = @consumer_key
          config.consumer_secret    = @consumer_secret
          config.oauth_token        = @oauth_token
          config.oauth_token_secret = @oauth_token_secret
        end

        client = ::Twitter::Client.new
        client.update(message)
      end

    end
  end
end
