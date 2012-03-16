# encoding: utf-8

# Load the HipChat library from the gem
Backup::Dependency.load('hipchat')

module Backup
  module Notifier
    class Hipchat < Base

      ##
      # The Hipchat API token
      attr_accessor :token

      ##
      # Who the notification should appear from
      attr_accessor :from

      ##
      # The rooms that should be notified
      attr_accessor :rooms_notified

      ##
      # Notify users in the room
      attr_accessor :notify_users

      ##
      # The background color of a success message.
      # One of :yellow, :red, :green, :purple, or :random. (default: yellow)
      attr_accessor :success_color

      ##
      # The background color of a warning message.
      # One of :yellow, :red, :green, :purple, or :random. (default: yellow)
      attr_accessor :warning_color

      ##
      # The background color of an error message.
      # One of :yellow, :red, :green, :purple, or :random. (default: yellow)
      attr_accessor :failure_color

      def initialize(model, &block)
        super(model)

        @notify_users   ||= false
        @rooms_notified ||= []
        @success_color  ||= 'yellow'
        @warning_color  ||= 'yellow'
        @failure_color  ||= 'yellow'

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
        name, color = case status
                      when :success then ['Success', success_color]
                      when :warning then ['Warning', warning_color]
                      when :failure then ['Failure', failure_color]
                      end
        message = "[Backup::%s] #{@model.label} (#{@model.trigger})" % name
        send_message(message, color)
      end

      def send_message(msg, color)
        client = HipChat::Client.new(token)
        [rooms_notified].flatten.each do |room|
          client[room].send(from, msg, :color => color, :notify => notify_users)
        end
      end

    end
  end
end
