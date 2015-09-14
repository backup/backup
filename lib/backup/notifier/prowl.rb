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
        @message = lambda do |model, data|
          "#{ model.label } (#{ model.trigger })"
        end
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
        send_message(status)
      end

      def send_message(status)
        uri = 'https://api.prowlapp.com/publicapi/add'
        status_data = status_data_for(status)
        data = {
          :application  => application,
          :apikey       => api_key,
          :event        => status_data[:message],
          :description  => message.call(model, :status => status_data)
        }
        options = {
          :headers  => { 'Content-Type' => 'application/x-www-form-urlencoded' },
          :body     => URI.encode_www_form(data)
        }
        options.merge!(:expects => 200) # raise error if unsuccessful
        Excon.post(uri, options)
      end

    end
  end
end
