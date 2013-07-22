# encoding: utf-8
require 'uri'

module Backup
  module Notifier
    class Prowl < Base

      ##
      # Application name
      # Tell something like your server name. Example: "Server1 Backup"
      attr_accessor :application

      ##
      # API-Key
      # Create a Prowl account and request an API key on prowlapp.com.
      attr_accessor :api_key

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
              when :warning then '[Backup::Warning]'
              when :failure then '[Backup::Failure]'
              end
        send_message(tag)
      end

      def send_message(message)
        uri = 'https://api.prowlapp.com/publicapi/add'
        data = {
          :application  => application,
          :apikey       => api_key,
          :event        => message,
          :description  => "#{ model.label } (#{ model.trigger })"
        }
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
