# encoding: utf-8

module Backup
  module Compressor
    class Gzip < Base

      ##
      # Tells Backup::Compressor::Gzip to compress
      # better rather than faster when set to true
      attr_writer :best

      ##
      # Tells Backup::Compressor::Gzip to compress
      # faster rather than better when set to true
      attr_writer :fast

      ##
      # Creates a new instance of Backup::Compressor::Gzip and
      # configures it to either compress faster or better
      def initialize(&block)
        @best = false
        @fast = false

        instance_eval(&block) if block_given?
      end

      ##
      # Performs the compression of the packages backup file
      def perform!
        log!
        run("#{ utility(:gzip) } #{ options } '#{ Backup::Model.file }'")
        Backup::Model.extension += '.gz'
      end

    private

      ##
      # Combines the provided options and returns a gzip options string
      def options
        (best + fast).join("\s")
      end

      ##
      # Returns the gzip option syntax for compressing
      # better when @best is set to true
      def best
        return ['--best'] if @best; []
      end

      ##
      # Returns the gzip option syntax for compressing
      # faster when @fast is set to true
      def fast
        return ['--fast'] if @fast; []
      end

    end
  end
end
