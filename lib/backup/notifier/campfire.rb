# encoding: utf-8
require 'json'

module Backup
  module Notifier
    class Campfire < Base

      ##
      # Campfire api authentication token
      attr_accessor :api_token

      ##
      # Campfire account's subdomain
      attr_accessor :subdomain

      ##
      # Campfire account's room id
      attr_accessor :room_id

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
        message = "#{ tag } #{ model.label } (#{ model.trigger })"
        send_message(message)
      end

      def send_message(message)
        uri = "https://#{ subdomain }.campfirenow.com/room/#{ room_id }/speak.json"
        options = {
          :headers  => { 'Content-Type' => 'application/json' },
          :body     => JSON.dump(
            { :message => { :body => message, :type => 'Textmessage' } }
          )
        }
        options.merge!(:user => api_token, :password => 'x') # Basic Auth
        options.merge!(:expects => 201) # raise error if unsuccessful
        Excon.post(uri, options)
      end

    end
  end
end
