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

      # The Hipchat API token
      attr_accessor :token

      # Who the notification should appear from
      attr_accessor :from

      # The rooms that should be notified
      attr_accessor :rooms_notified

      # The background color of a success message. One of :yellow, :red, :green, :purple, or :random. (default: yellow)
      attr_accessor :success_color

      # The background color of an error message. One of :yellow, :red, :green, :purple, or :random. (default: yellow)
      attr_accessor :failure_color

      # Notify users in the room
      attr_accessor :notify_users

      attr_accessor :model

      def initialize(&block)
        load_defaults!

        instance_eval(&block) if block_given?

        set_defaults!
      end

      def perform!(model, exception = false)
        @model = model

        if notify_on_success? and exception.eql?(false)
          log!
          notify_success!
        elsif notify_on_failure? and not exception.eql?(false)
          log!
          notify_failure!(exception)
        end
      end

      private

      def send_message(msg, color, notify)
        client = HipChat::Client.new(@hipchat_options[:token])
        @hipchat_options[:rooms_notified].each do |room|
          client[room].send(@hipchat_options[:from], msg, :color => color, :notify => notify)
        end
      end

      def notify_success!
        send_message("[Backup::Succeeded] #{model.label} (#{ File.basename(Backup::Model.file) })", @hipchat_options[:success_color], @hipchat_options[:notify_users])
      end

      def notify_failure!(exception)
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
