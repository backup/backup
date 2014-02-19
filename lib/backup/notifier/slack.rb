# encoding: utf-8
require 'uri'
require 'json'

module Backup
  module Notifier
    class Slack < Base

      ##
      # The Team name
      attr_accessor :team

      ##
      # The Integration Token
      attr_accessor :token

      ##
      # The channel to send messages to
      attr_accessor :channel

      ##
      # The username to display along with the notification
      attr_accessor :username

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
        tag = case status
              when :success then '[Backup::Success]'
              when :failure then '[Backup::Failure]'
              when :warning then '[Backup::Warning]'
              end
        message = "#{ tag } #{ model.label } (#{ model.trigger })"
        send_message(message)
      end

      def send_message(message)
        data = { text: message }
        [:channel, :username].each do |param|
          val = send(param)
          data.merge!(param => val) if val
        end
        options = {
          :headers  => { 'Content-Type' => 'application/x-www-form-urlencoded' },
          :body     => URI.encode_www_form(payload: JSON.dump(data))
        }
        options.merge!(:expects => 200) # raise error if unsuccessful
        Excon.post(uri, options)
      end

      def uri
        @uri ||= "https://#{team}.slack.com/services/hooks/incoming-webhook?token=#{token}"
      end
    end
  end
end
