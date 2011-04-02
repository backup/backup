# encoding: utf-8

module Backup
  class Logger

    ##
    # Outputs a messages to the console and writes it to the backup.log
    def self.message(string)
      puts    loggify(:message, string, :green)
      to_file loggify(:message, string)
    end

    ##
    # Outputs an error to the console and writes it to the backup.log
    def self.error(string)
      puts    loggify(:error, string, :red)
      to_file loggify(:error, string)
    end

    ##
    # Outputs a notice to the console and writes it to the backup.log
    def self.warn(string)
      puts    loggify(:warning, string, :yellow)
      to_file loggify(:warning, string)
    end

    ##
    # Outputs the data as if it were a regular 'puts' command,
    # but also logs it to the backup.log
    def self.normal(string)
      puts    string
      to_file string
    end

    ##
    # Silently logs data to the log file
    def self.silent(string)
      to_file loggify(:silent, string)
    end

    ##
    # Returns the time in [YYYY/MM/DD HH:MM:SS] format
    def self.time
      Time.now.strftime("%Y/%m/%d %H:%M:%S")
    end

    ##
    # Builds the string in a log format with the date/time, the type (colorized)
    # based on whether it's a message, notice or error, and the message itself.
    # ANSI color codes are only used in the console, and are not written to the log
    # since it doesn't do anything and just adds more unnecessary bloat to the log file
    def self.loggify(type, string, color = false)
      return "[#{time}][#{type}] #{string}" unless color
      "[#{time}][#{send(color, type)}] #{string}"
    end

    ##
    # Writes (appends) a string to the backup.log file
    def self.to_file(string)
      File.open(File.join(LOG_PATH, 'backup.log'), 'a') do |file|
        file.write("#{string}\n")
      end
    end

    ##
    # Invokes the #colorize method with the provided string
    # and the color code "32" (for green)
    def self.green(string)
      colorize(string, 32)
    end

    ##
    # Invokes the #colorize method with the provided string
    # and the color code "33" (for yellow)
    def self.yellow(string)
      colorize(string, 33)
    end

    ##
    # Invokes the #colorize method the with provided string
    # and the color code "31" (for red)
    def self.red(string)
      colorize(string, 31)
    end

    ##
    # Wraps the provided string in colorizing tags to provide
    # easier to view output to the client
    def self.colorize(string, code)
      "\e[#{code}m#{string}\e[0m"
    end

  end
end
