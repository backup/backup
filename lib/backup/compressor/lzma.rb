# encoding: utf-8

module Backup
  module Compressor
    class Lzma < Base

      ##
      # Tells Backup::Compressor::Lzma to compress
      # better (-9) rather than faster when set to true
      attr_writer :best

      ##
      # Tells Backup::Compressor::Lzma to compress
      # faster (-1) rather than better when set to true
      attr_writer :fast

      ##
      # Creates a new instance of Backup::Compressor::Lzma and
      # configures it to either compress faster or better
      # Lzma compresses by default with -9 (best compression)
      # and lower block sizes don't make things significantly faster
      # (according to official bzip2 docs)
      def initialize(&block)
        load_defaults!

        @best ||= false
        @fast ||= false

        instance_eval(&block) if block_given?
      end

      ##
      # Performs the compression of the packages backup file
      def perform!
        log!
        p "#{ utility(:lzma) } #{ options } '#{ Backup::Model.file }'"
        p run("#{ utility(:lzma) } #{ options } '#{ Backup::Model.file }'")
        Backup::Model.extension += '.lzma'
      end

    private

      ##
      # Combines the provided options and returns a bzip2 options string
      def options
        (best + fast).join("\s")
      end

      ##
      # Returns the lzma option syntax for compressing
      # setting @best to true is redundant, as lzma compresses best by default
      def best
        return ['--best'] if @best; []
      end

      ##
      # Returns the lzma option syntax for compressing
      # (not significantly) faster when @fast is set to true
      def fast
        return ['--fast'] if @fast; []
      end
    end
  end
end
