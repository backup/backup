# encoding: utf-8

if RUBY_VERSION < '1.9.0'
  Backup::Dependency.load('json')
else
  require 'json'
end

# Load HTTParty
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
      # The background color of a success message. One of :yellow, :red, :green, :purple, or :random. (default: yellow)
      attr_accessor :success_color

      ##
      # The background color of a warning message. One of :yellow, :red, :green, :purple, or :random. (default: yellow)
      attr_accessor :warning_color

      ##
      # The background color of an error message. One of :yellow, :red, :green, :purple, or :random. (default: yellow)
      attr_accessor :failure_color

      ##
      # Notify users in the room
      attr_accessor :notify_users

      ##
      # Performs the notification
      # Extends from super class. Must call super(model, exception).
      # If any pre-configuration needs to be done, put it above the super(model, exception)
      def perform!(model, exception = false)
        @rooms_notified = [rooms_notified].flatten
        super(model, exception)
      end

    private

      def send_message(msg, color, notify)
        client = HipChat::Client.new(token)
        rooms_notified.each do |room|
          client[room].send(from, msg, :color => color, :notify => notify)
        end
      end

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
        message = "[Backup::%s] #{model.label} (#{model.trigger})" % name
        send_message(message, color, notify_users)
      end

      def set_defaults!
        @success_color ||= 'yellow'
        @warning_color ||= 'yellow'
        @failure_color ||= 'yellow'
        @notify_users  ||= false
      end
    end
  end
end
