# encoding: utf-8

module Backup
  module Compressor
    class Gzip < Base

      ##
      # Tells Backup::Compressor::Gzip to compress
      # better rather than faster when set to true
      attr_accessor :best

      ##
      # Tells Backup::Compressor::Gzip to compress
      # faster rather than better when set to true
      attr_accessor :fast

      ##
      # Creates a new instance of Backup::Compressor::Gzip and
      # configures it to either compress faster or better
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
        yield "#{ utility(:gzip) }#{ options }", '.gz'
      end

      private

      ##
      # Returns the gzip option syntax for compressing
      def options
        " #{ '--best ' if @best }#{ '--fast' if @fast }".rstrip
      end

    end
  end
end
