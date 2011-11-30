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
        @rooms_notified = [@hipchat_options[:rooms_notified]] unless @hipchat_options[:rooms_notified].is_a? Array
        super(model, exception)
      end

    private

      def send_message(msg, color, notify)
        client = HipChat::Client.new(@hipchat_options[:token])
        @rooms_notified.each do |room|
          client[room].send(@hipchat_options[:from], msg, :color => color, :notify => notify)
        end
      end

      def notify_success!
        send_message("[Backup::Succeeded] #{model.label} (#{ File.basename(Backup::Model.file) })", @hipchat_options[:success_color], @hipchat_options[:notify_users])
      end

      def notify_failure!
        send_message("[Backup::Failed] #{model.label} (#{ File.basename(Backup::Model.file) })", @hipchat_options[:failure_color], @hipchat_options[:notify_users])
      end

      def set_defaults!
        @hipchat_options = {
          :token => @token,
          :from => @from,
          :rooms_notified => @rooms_notified,
          :success_color => @success_color || 'yellow',
          :failure_color => @failure_color || 'yellow',
          :notify_users => @notify_users
        }
      end
    end
  end
end
