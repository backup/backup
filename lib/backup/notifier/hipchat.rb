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

      def initialize(&block)
        load_defaults!

        instance_eval(&block) if block_given?

        set_defaults!
      end

      private

      def set_defaults
        @client = HipChat::Client.new(@token)
      end
    end
  end
end
