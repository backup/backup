# encoding: utf-8

module Backup
  module Compressor
    class Custom < Base

      ##
      # Specify the system command to invoke a compressor,
      # including any command-line arguments.
      # e.g. @compressor.command = 'pbzip2 -p2 -4'
      #
      # The data to be compressed will be piped to the command's STDIN,
      # and it should write the compressed data to STDOUT.
      # i.e. `cat file.tar | %command% > file.tar.%extension%`
      attr_accessor :command

      ##
      # File extension to append to the compressed file's filename.
      # e.g. @compressor.extension = '.bz2'
      attr_accessor :extension

      ##
      # Initializes a new custom compressor.
      def initialize(&block)
        load_defaults!

        instance_eval(&block) if block_given?

        @cmd = set_cmd
        @ext = set_ext
      end

      private

      ##
      # Return the command line using the full path.
      # Ensures the command exists and is executable.
      def set_cmd
        parts = @command.to_s.split(' ')
        parts[0] = utility(parts[0])
        parts.join(' ')
      end

      ##
      # Return the extension given without whitespace.
      # If extension was not set, return an empty string
      def set_ext
        @extension.to_s.strip
      end

    end
  end
end
