# encoding: utf-8

module Backup
  module Logger
    class << self

      ##
      # Outputs a messages to the console and writes it to the backup.log
      def message(string)
        to_console  loggify(string, :message, :green)
        to_file     loggify(string, :message)
      end

      ##
      # Outputs an error to the console and writes it to the backup.log
      # Called when an Exception has caused the backup process to abort.
      def error(string)
        to_console  loggify(string, :error,   :red), true
        to_file     loggify(string, :error)
      end

      ##
      # Outputs a notice to the console and writes it to the backup.log
      # Sets #has_warnings? true so :on_warning notifications will be sent
      def warn(string)
        @has_warnings = true
        to_console  loggify(string, :warning, :yellow), true
        to_file     loggify(string, :warning)
      end

      # Outputs the data as if it were a regular 'puts' command,
      # but also logs it to the backup.log
      def normal(string)
        to_console  loggify(string)
        to_file     loggify(string)
      end

      ##
      # Silently logs data to the log file
      def silent(string)
        to_file     loggify(string, :silent)
      end

      ##
      # Returns an Array of all messages written to the log file for this session
      def messages
        @messages ||= []
      end

      ##
      # Returns true if any warnings have been issued
      def has_warnings?
        @has_warnings ||= false
      end

      private

      ##
      # Returns the time in [YYYY/MM/DD HH:MM:SS] format
      def time
        Time.now.strftime("%Y/%m/%d %H:%M:%S")
      end

      ##
      # Receives a String, or an Object that responds to #to_s (e.g. an
      # Exception), from one of the messaging methods and converts it into an
      # Array of Strings, split on newline separators. Each line is then
      # formatted into a log format based on the given options, and the Array
      # returned to be passed to to_console() and/or to_file().
      def loggify(string, type = false, color = false)
        lines = string.to_s.split("\n")
        if type
          type = send(color, type) if color
          time_now = time
          lines.map {|line| "[#{time_now}][#{type}] #{line}" }
        else
          lines
        end
      end

      ##
      # Receives an Array of Strings to be written to the console.
      def to_console(lines, stderr = false)
        return if quiet?
        lines.each {|line| stderr ? Kernel.warn(line) : puts(line) }
      end

      ##
      # Receives an Array of Strings to be written to the log file.
      def to_file(lines)
        File.open(File.join(LOG_PATH, 'backup.log'), 'a') do |file|
          lines.each {|line| file.puts line }
        end
        messages.push(*lines)
      end

      ##
      # Invokes the #colorize method with the provided string
      # and the color code "32" (for green)
      def green(string)
        colorize(string, 32)
      end

      ##
      # Invokes the #colorize method with the provided string
      # and the color code "33" (for yellow)
      def yellow(string)
        colorize(string, 33)
      end

      ##
      # Invokes the #colorize method the with provided string
      # and the color code "31" (for red)
      def red(string)
        colorize(string, 31)
      end

      ##
      # Wraps the provided string in colorizing tags to provide
      # easier to view output to the client
      def colorize(string, code)
        "\e[#{code}m#{string}\e[0m"
      end

      ##
      # Returns 'true' (boolean) if the QUIET constant is defined
      # By default it isn't defined, only when initializing Backup using
      # the '--quiet' (or '-q') option in the CLI
      # (e.g. backup perform -t my_backup --quiet)
      def quiet?
        const_defined?(:QUIET) && QUIET
      end

    end
  end
end
