# encoding: utf-8

module Backup
  module Compressor
    class Gzip
      include Backup::CLI

      ##
      # Contains additional options for Backup::Compressor::Gzip
      attr_accessor :additional_options

      ##
      # Creates a new instance of Backup::Compressor::Gzip and
      # configures the (optional) additional_options attribute
      def initialize(&block)
        @additional_options = Array.new

        instance_eval(&block) if block_given?
      end

      ##
      # Performs the compression of the packages backup file
      def perform!
        run("#{ utility(:gzip) } #{ options } '#{ File.join(TMP_PATH, "#{ TIME }.#{ TRIGGER }.#{ Backup::Model.extension }") }'")
        Backup::Model.extension += '.gz'
      end

    private

      ##
      # Generates the options (String) based on the additional_options (Array) parameters
      # so that it works with the gzip command
      def options
        additional_options.join("\s")
      end
    end
  end
end
