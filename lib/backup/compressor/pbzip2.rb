# encoding: utf-8

module Backup
  module Compressor
    class Pbzip2 < Base

      ##
      # Tells Backup::Compressor::Lzma to compress
      # better (-9) rather than faster when set to true
      attr_accessor :best

      ##
      # Tells Backup::Compressor::Lzma to compress
      # faster (-1) rather than better when set to true
      attr_accessor :fast

      ##
      # Tells Backup::Compressor::Pbzip2 how many processors to use.
      # Autodetects the number of active CPUs by default.
      attr_accessor :processors

      ##
      # Creates a new instance of Backup::Compressor::Pbzip2
      def initialize(&block)
        load_defaults!

        @best       ||= false
        @fast       ||= false
        @processors ||= false

        instance_eval(&block) if block_given?

        @cmd = "#{ utility(:pbzip2) }#{ options }"
        @ext = '.bz2'
      end

      ##
      # Yields to the block the compressor command and filename extension.
      def compress_with
        Backup::Logger.warn(
          "[DEPRECATION WARNING]\n" +
          "  Compressor::Pbzip2 is being deprecated as of backup v.3.0.24\n" +
          "  and will soon be removed. Please see the Compressors wiki page at\n" +
          "  https://github.com/meskyanichi/backup/wiki/Compressors"
        )
        super
      end

      private

      def options
        level = (' --best' if @best) || (' --fast' if @fast)
        cpus  = " -p#{ @processors }" if @processors
        "#{ level }#{ cpus }"
      end

    end
  end
end
