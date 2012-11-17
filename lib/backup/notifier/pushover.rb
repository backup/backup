# encoding: utf-8
require 'net/https'

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
      # The user's device identifier to sent he message directly to that device rather than all of the user's devices
      attr_accessor :device

      ##
      # The message title
      attr_accessor :title

      ##
      # The priority of the notification
      attr_accessor :priority

      def initialize(model, &block)
        super(model)

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
               when :failure then 'Failure'
               when :warning then 'Warning'
               end
        message = "[Backup::%s] #{@model.label} (#{@model.trigger})" % name

        send_message(message)
      end

      # Push a message via the Pushover API
      def send_message(message)
        url = URI.parse("https://api.pushover.net/1/messages.json")

        request = Net::HTTP::Post.new(url.path)
        request.set_form_data(parameters.merge ({:message => message}))
        response = Net::HTTP.new(url.host, url.port)

        response.use_ssl = true
        response.verify_mode = OpenSSL::SSL::VERIFY_PEER

        response.start {|http| http.request(request) }
      end

      # List available parameters
      def parameters
        @values = {}
        [:token, :user, :message, :title, :priority, :device].each { |k| @values.merge! k => self.instance_variable_get("@#{k}") }
        @values
      end
    end
  end
end
