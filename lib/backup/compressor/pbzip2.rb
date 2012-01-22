# encoding: utf-8

module Backup
  module Compressor
    class Pbzip2 < Base

      ##
      # Tells Backup::Compressor::Pbzip2 to compress
      # better (-9) rather than faster when set to true
      attr_accessor :best

      ##
      # Tells Backup::Compressor::Pbzip2 to compress
      # faster (-1) rather than better when set to true
      attr_accessor :fast

      ##
      # Tells Backup::Compressor::Pbzip2 how many processors
      # use, by default autodetect is used
      attr_accessor :processors

      ##
      # Creates a new instance of Backup::Compressor::Pbzip2 and
      # configures it to either compress faster or better
      # bzip2 compresses by default with -9 (best compression)
      # and lower block sizes don't make things significantly faster
      # (according to official bzip2 docs)
      def initialize(&block)
        super

        @best       ||= false
        @fast       ||= false
        @processors ||= false

        instance_eval(&block) if block_given?
      end

      ##
      # Yields to the block the compressor command with options
      # and it's filename extension.
      def compress_with
        log!
        yield "#{ utility(:pbzip2) }#{ options }", '.bz2'
      end

      private

      ##
      # Returns the gzip option syntax for compressing
      def options
        " #{ '--best ' if @best }#{ '--fast ' if @fast }#{ "-p#{@processors}" if @processors }".rstrip
      end

    end
  end
end
