# encoding: utf-8
require 'hipchat'

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
        super
        instance_eval(&block) if block_given?

        @notify_users   ||= false
        @rooms_notified ||= []
        @success_color  ||= 'yellow'
        @warning_color  ||= 'yellow'
        @failure_color  ||= 'yellow'
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
        tag, color = case status
                     when :success then ['[Backup::Success]', success_color]
                     when :warning then ['[Backup::Warning]', warning_color]
                     when :failure then ['[Backup::Failure]', failure_color]
                     end
        message = "#{ tag } #{ model.label } (#{ model.trigger })"
        send_message(message, color)
      end

      # Hipchat::Client will raise an error if unsuccessful.
      def send_message(msg, color)
        client = HipChat::Client.new(token)
        rooms_to_notify.each do |room|
          client[room].send(from, msg, :color => color, :notify => notify_users)
        end
      end

      def rooms_to_notify
        Array(rooms_notified).map {|r| r.split(',').map(&:strip) }.flatten
      end

    end
  end
end
