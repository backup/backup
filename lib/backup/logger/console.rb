# encoding: utf-8

module Backup
  module Logger
    class Console
      class Options
        ##
        # Disables all console output.
        #
        # This may also be set on the command line using +--quiet+.
        #
        # If +--no-quiet+ is used on the command line, console output
        # will be enabled and any setting here will be ignored.
        #
        # @param [Boolean, nil]
        # @return [Boolean, nil] Default: +false+
        attr_reader :quiet

        def initialize
          @quiet = false
        end

        def enabled?
          !quiet
        end

        def quiet=(val)
          @quiet = val unless quiet.nil?
        end
      end

      COLORS = {
        :info   => "\e[32m%s\e[0m", # green
        :warn   => "\e[33m%s\e[0m", # yellow
        :error  => "\e[31m%s\e[0m"  # red
      }

      def initialize(options = nil); end

      def log(message)
        color = COLORS[message.level]
        lines = message.formatted_lines.map {|line| color % line }
        (message.level == :info ? $stdout : $stderr).puts lines
      end

    end
  end
end
