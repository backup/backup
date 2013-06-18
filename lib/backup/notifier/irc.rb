# encoding: utf-8
require 'cinch'

module Backup
  module Notifier
    class IRC < Base

      ##
      # Bot nickname
      attr_accessor :nick

      ##
      # Channel to notify
      attr_accessor :channel

      ##
      # Server port
      attr_accessor :port

      ##
      # True to connect using ssl, false otherwise
      attr_accessor :ssl

      ##
      # Server hostname
      attr_accessor :server

      def initialize(model, &block)
        super
        instance_eval(&block) if block_given?

        @nick ||= "backup"
        @port ||= 6667
        @ssl ||= 0
        @server ||= "irc.oftc.net"
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
      # : Notification will be sent, including a copy of the current
      # : backup log, if `on_warning` or `on_success` is `true`.
      #
      # `:failure`
      # : The backup operation failed.
      # : Notification will be sent, including a copy of the current
      # : backup log, if `on_failure` is `true`.
      #
      def notify!(status)
        tag = case status
              when :success then '[Backup::Success]'
              when :warning then '[Backup::Warning]'
              when :failure then '[Backup::Failure]'
              end

        message = "#{ tag } #{ model.label } (#{ model.trigger }) (@ #{ model.time })"
        server = @server
        nick = @nick
        port = @port
        ssl = @ssl
        channel = @channel

        bot = Cinch::Bot.new do
          configure do |config|
            config.server = server
            config.nick = nick
            config.port = port
            config.ssl.use = ssl
          end

          on :connect do
            Channel(channel).msg(message)
            bot.quit()
          end
        end
        bot.start
      end
    end
  end
end
