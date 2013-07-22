# encoding: utf-8
require 'uri'

module Backup
  module Notifier
    class Pushover < Base

      ##
      # The API User Token
      attr_accessor :user

      ##
      # The API Application Token
      attr_accessor :token

      ##
      # The user's device identifier to sent the message directly to,
      # rather than all of the user's devices
      attr_accessor :device

      ##
      # The message title
      attr_accessor :title

      ##
      # The priority of the notification
      attr_accessor :priority

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
        uri = 'https://api.pushover.net/1/messages.json'
        data = { :user => user, :token => token, :message => message }
        [:device, :title, :priority].each do |param|
          val = send(param)
          data.merge!(param => val) if val
        end
        options = {
          :headers  => { 'Content-Type' => 'application/x-www-form-urlencoded' },
          :body     => encode_www_form(data)
        }
        options.merge!(:expects => 200) # raise error if unsuccessful
        Excon.post(uri, options)
      end

    end
  end
end
