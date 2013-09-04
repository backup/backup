# encoding: utf-8

module Backup
  class Logger
    class Syslog
      class Options
        ##
        # Enables logging to the system's Syslog compatible logger.
        #
        # This may also be enabled using +--syslog+ on the command line.
        #
        # If +--no-syslog+ is used on the command line, this will be
        # disabled and any settings here will be ignored.
        #
        # @param [Boolean, nil]
        # @return [Boolean, nil] Default: +false+
        attr_reader :enabled

        ##
        # Specify the identification string to be used with Syslog.
        #
        # @param [String]
        # @return [String] Default: 'backup'
        attr_accessor :ident

        ##
        # Specify the options to be used with Syslog.
        #
        # See the Ruby Standard Library documentation for +Syslog+ for more info.
        # http://rdoc.info/stdlib/syslog/Syslog.open
        #
        # Note that setting this to +nil+ will cause this to default
        # to a setting of +Syslog::LOG_PID | Syslog::LOG_CONS+
        #
        # @param [Integer]
        # @return [Integer] Default: +Syslog::LOG_PID+
        attr_accessor :options

        ##
        # Specify the facility to be used with Syslog.
        #
        # See the Ruby Standard Library documentation for +Syslog+ for more info.
        # http://rdoc.info/stdlib/syslog/Syslog.open
        #
        # Note that setting this to +nil+ will cause this to default
        # to a setting of +Syslog::LOG_USER+
        #
        # @param [Integer]
        # @return [Integer] Default: +Syslog::LOG_LOCAL0+
        attr_accessor :facility

        ##
        # Specify the priority level to be used for +:info+ messages.
        #
        # See the Ruby Standard Library documentation for +Syslog+ for more info.
        # http://rdoc.info/stdlib/syslog/Syslog.log
        #
        # @param [Integer]
        # @return [Integer] Default: +Syslog::LOG_INFO+
        attr_accessor :info

        ##
        # Specify the priority level to be used for +:warn+ messages.
        #
        # See the Ruby Standard Library documentation for +Syslog+ for more info.
        # http://rdoc.info/stdlib/syslog/Syslog.log
        #
        # @param [Integer]
        # @return [Integer] Default: +Syslog::LOG_WARNING+
        attr_accessor :warn

        ##
        # Specify the priority level to be used for +:error+ messages.
        #
        # See the Ruby Standard Library documentation for +Syslog+ for more info.
        # http://rdoc.info/stdlib/syslog/Syslog.log
        #
        # @param [Integer]
        # @return [Integer] Default: +Syslog::LOG_ERR+
        attr_accessor :error

        def initialize
          @enabled = false
          @ident = 'backup'
          @options = ::Syslog::LOG_PID
          @facility = ::Syslog::LOG_LOCAL0
          @info = ::Syslog::LOG_INFO
          @warn = ::Syslog::LOG_WARNING
          @error = ::Syslog::LOG_ERR
        end

        def enabled?
          !!enabled
        end

        def enabled=(val)
          @enabled = val unless enabled.nil?
        end
      end

      def initialize(options)
        @options = options
      end

      ##
      # Message lines are sent without formatting (timestamp, level),
      # since Syslog will provide it's own timestamp and priority.
      def log(message)
        level = @options.send(message.level)
        ::Syslog.open(@options.ident, @options.options, @options.facility) do |s|
          message.lines.each {|line| s.log(level, '%s', line) }
        end
      end
    end
  end
end
