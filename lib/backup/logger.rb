# encoding: utf-8

require 'backup/logger/console'
require 'backup/logger/logfile'
require 'backup/logger/syslog'

module Backup
  module Logger

    class Config
      class Logger < Struct.new(:class, :options)
        def enabled?
          options.enabled?
        end
      end

      DSL = Struct.new(:console, :logfile, :syslog)

      attr_reader :loggers, :dsl

      def initialize
        @loggers = [
          Logger.new(Console, Console::Options.new),
          Logger.new(Logfile, Logfile::Options.new),
          Logger.new(Syslog, Syslog::Options.new)
        ]
        @dsl = DSL.new(*@loggers.map(&:options))
      end
    end

    ##
    # All messages sent to the Logger are stored in Logger.messages
    # and sent to all enabled logger's #log method as Message objects.
    class Message < Struct.new(:time, :level, :lines)
      ##
      # Returns an Array of the message lines in the following format:
      #
      #   [YYYY/MM/DD HH:MM:SS][level] message line text
      def formatted_lines
        timestamp = time.strftime("%Y/%m/%d %H:%M:%S")
        lines.map {|line| "[#{ timestamp }][#{ level }] #{ line }" }
      end
    end

    class << self
      ##
      # Returns an Array of Message objects for all logged messages received.
      # These are used to attach log files to Mail notifications.
      attr_reader :messages

      ##
      # Allows the Logger to be configured.
      #
      #   # shown with their default values
      #   Backup::Logger.configure do
      #     # Console options:
      #     console.quiet = false
      #
      #     # Logfile options:
      #     logfile.enabled   = true
      #     logfile.log_path  = 'log'
      #     logfile.max_bytes = 500_000
      #
      #     # Syslog options:
      #     syslog.enabled  = false
      #     syslog.ident    = 'backup'
      #     syslog.options  = Syslog::LOG_PID
      #     syslog.facility = Syslog::LOG_LOCAL0
      #     syslog.info     = Syslog::LOG_INFO
      #     syslog.warn     = Syslog::LOG_WARNING
      #     syslog.error    = Syslog::LOG_ERR
      #   end
      #
      # See each Logger's Option class for details.
      # @see Console::Options
      # @see Logfile::Options
      # @see Syslog::Options
      def configure(&block)
        @config.dsl.instance_eval(&block)
      end

      ##
      # Sends a message to the Logger using the specified log level.
      # +obj+ may be any Object that responds to #to_s (i.e. an Exception)
      [:info, :warn, :error].each do |level|
        define_method level, lambda {|obj| log(obj, level) }
      end

      ##
      # Returns true if any +:warn+ level messages have been received.
      def has_warnings?
        @has_warnings
      end

      ##
      # The Logger is available as soon as Backup is loaded, and stores all
      # messages it receives. Since the Logger may be configured via the
      # command line and/or the user's +config.rb+, no messages are sent
      # until configuration can be completed. (see CLI#perform)
      #
      # Once configuration is completed, this method is called to activate
      # all enabled loggers and send them any messages that have been received
      # up to this point. From this point onward, these loggers will be sent
      # all messages as soon as they're received.
      def start!
        @config.loggers.each do |logger|
          @loggers << logger.class.new(logger.options) if logger.enabled?
        end
        @messages.each do |message|
          @loggers.each {|logger| logger.log(message) }
        end
      end

      ##
      # Called after each backup model/trigger has been performed.
      def clear!
        messages.clear
        @has_warnings = false
      end

      ##
      # If errors are encountered by Backup::CLI while preparing to perform
      # the backup jobs, this method is called to dump all messages to the
      # console before Backup exits.
      def abort!
        console = Console.new
        console.log(@messages.shift) until @messages.empty?
      end

      private

      def initialize!
        @messages = []
        @loggers = []
        @config = Config.new
        @has_warnings = false
      end

      def log(obj, level)
        @has_warnings ||= level == :warn
        message = Message.new(Time.now, level, obj.to_s.split("\n"))
        @messages << message
        @loggers.each {|logger| logger.log(message) }
      end

    end

    initialize!
  end
end
