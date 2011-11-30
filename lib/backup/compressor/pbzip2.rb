# encoding: utf-8

module Backup
  module Compressor
    class Pbzip2 < Base

      ##
      # Tells Backup::Compressor::Pbzip2 to compress
      # better (-9) rather than faster when set to true
      attr_writer :best

      ##
      # Tells Backup::Compressor::Pbzip2 to compress
      # faster (-1) rather than better when set to true
      attr_writer :fast

      ##
      # Tells Backup::Compressor::Pbzip2 how many processors
      # use, by default autodetect is used
      attr_writer :processors

      ##
      # Creates a new instance of Backup::Compressor::Pbzip2 and
      # configures it to either compress faster or better
      # bzip2 compresses by default with -9 (best compression)
      # and lower block sizes don't make things significantly faster
      # (according to official bzip2 docs)
      def initialize(&block)
        load_defaults!

        @best ||= false
        @fast ||= false
        @processors ||= nil

        instance_eval(&block) if block_given?
      end

      ##
      # Performs the compression of the packages backup file
      def perform!
        log!
        run("#{ utility(:pbzip2) } #{ options } '#{ Backup::Model.file }'")
        Backup::Model.extension += '.bz2'
      end

    private

      ##
      # Combines the provided options and returns a pbzip2 options string
      def options
        (best + fast + processors).join("\s")
      end

      ##
      # Returns the pbzip2 option syntax for compressing
      # setting @best to true is redundant, as pbzip2 compresses best by default
      def best
        return ['--best'] if @best; []
      end

      ##
      # Returns the pbzip2 option syntax for compressing
      # (not significantly) faster when @fast is set to true
      def fast
        return ['--fast'] if @fast; []
      end

      ##
      # Returns the pbzip2 option syntax for compressing
      # using given count of cpus
      def processors
        return ['-p' + @processors.to_s] if @processors; []
      end
    end
  end
end
