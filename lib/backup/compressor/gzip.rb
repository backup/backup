# encoding: utf-8

module Backup
  module Compressor
    class Gzip < Base

      ##
      # Specify the level of compression to use.
      #
      # Values should be a single digit from 1 to 9.
      # Note that setting the level to either extreme may or may not
      # give the desired result. Be sure to check the documentation
      # for the compressor being used.
      #
      # The default `level` is 6.
      attr_accessor :level

      attr_deprecate :fast, :version => '3.0.24',
                     :replacement => :level,
                     :value => lambda {|val| val ? 1 : nil }
      attr_deprecate :best, :version => '3.0.24',
                     :replacement => :level,
                     :value => lambda {|val| val ? 9 : nil }

      ##
      # Creates a new instance of Backup::Compressor::Gzip
      def initialize(&block)
        load_defaults!

        @level ||= false

        instance_eval(&block) if block_given?

        @cmd = "#{ utility(:gzip) }#{ options }"
        @ext = '.gz'
      end

      private

      def options
        " -#{ @level }" if @level
      end

    end
  end
end
