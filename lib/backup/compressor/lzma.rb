# encoding: utf-8

module Backup
  module Compressor
    class Lzma < Base

      ##
      # Tells Backup::Compressor::Lzma to compress
      # better (-9) rather than faster when set to true
      attr_accessor :best

      ##
      # Tells Backup::Compressor::Lzma to compress
      # faster (-1) rather than better when set to true
      attr_accessor :fast

      ##
      # Creates a new instance of Backup::Compressor::Lzma
      def initialize(&block)
        load_defaults!

        @best ||= false
        @fast ||= false

        instance_eval(&block) if block_given?

        @cmd = "#{ utility(:lzma) }#{ options }"
        @ext = '.lzma'
      end


      ##
      # Yields to the block the compressor command and filename extension.
      def compress_with
        Backup::Logger.warn(
          "[DEPRECATION WARNING]\n" +
          "  Compressor::Lzma is being deprecated as of backup v.3.0.24\n" +
          "  and will soon be removed. Please see the Compressors wiki page at\n" +
          "  https://github.com/meskyanichi/backup/wiki/Compressors"
        )
        super
      end

      private

      def options
        (' --best' if @best) || (' --fast' if @fast)
      end

    end
  end
end
