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
      # Creates a new instance of Backup::Compressor::Lzma and
      # configures it to either compress faster or better
      # Lzma compresses by default with -9 (best compression)
      # and lower block sizes don't make things significantly faster
      # (according to official bzip2 docs)
      def initialize(&block)
        super

        @best ||= false
        @fast ||= false

        instance_eval(&block) if block_given?
      end

      ##
      # Yields to the block the compressor command with options
      # and it's filename extension.
      def compress_with
        log!
        yield "#{ utility(:lzma) }#{ options }", '.lzma'
      end

      private

      ##
      # Returns the option syntax for compressing
      def options
        " #{ '--best ' if @best }#{ '--fast' if @fast }".rstrip
      end

    end
  end
end
