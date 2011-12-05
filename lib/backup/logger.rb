# encoding: utf-8

module Backup
  module Logger
    class << self

      ##
      # Outputs a messages to the console and writes it to the backup.log
      def message(string)
        puts    loggify(:message, string, :green) unless quiet?
        to_file loggify(:message, string)
      end

      ##
      # Outputs an error to the console and writes it to the backup.log
      def error(string)
        puts    loggify(:error, string, :red) unless quiet?
        to_file loggify(:error, string)
      end

      ##
      # Outputs a notice to the console and writes it to the backup.log
      def warn(string)
        @has_warnings = true
        puts    loggify(:warning, string, :yellow) unless quiet?
        to_file loggify(:warning, string)
      end

      ##
      # Outputs the data as if it were a regular 'puts' command,
      # but also logs it to the backup.log
      def normal(string)
        puts    string unless quiet?
        to_file string
      end

      ##
      # Silently logs data to the log file
      def silent(string)
        to_file loggify(:silent, string)
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
      # Builds the string in a log format with the date/time, the type (colorized)
      # based on whether it's a message, notice or error, and the message itself.
      # ANSI color codes are only used in the console, and are not written to the log
      # since it doesn't do anything and just adds more unnecessary bloat to the log file
      def loggify(type, string, color = false)
        return "[#{time}][#{type}] #{string}" unless color
        "[#{time}][#{send(color, type)}] #{string}"
      end

      ##
      # Writes (appends) a string to the backup.log file
      def to_file(string)
        messages << string
        File.open(File.join(LOG_PATH, 'backup.log'), 'a') do |file|
          file.write("#{string}\n")
        end
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
      # the '--quite' (or '-q') option in the CLI (e.g. backup perform -t my_backup --quiet)
      def quiet?
        const_defined?(:QUIET) && QUIET
      end

    end
  end
end
