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
      attr_accessor :rsyncable

      attr_deprecate :fast, :version => '3.0.24',
                     :message => 'Use Gzip#level instead.',
                     :action => lambda {|klass, val|
                       klass.level = 1 if val
                     }
      attr_deprecate :best, :version => '3.0.24',
                     :message => 'Use Gzip#level instead.',
                     :action => lambda {|klass, val|
                       klass.level = 9 if val
                     }

      ##
      # Creates a new instance of Backup::Compressor::Gzip
      def initialize(&block)
        load_defaults!

        @level ||= false
        @rsyncable ||= false

        instance_eval(&block) if block_given?

        @cmd = "#{ utility(:gzip) }#{ options }"
        @ext = '.gz'
      end

      def self.has_rsyncable
        !!`gzip --help`.match(/--rsyncable/)
      end

      private

      def options
        opts = ""
        opts += " -#{ @level }" if @level
        if self.class.has_rsyncable
          opts += " --rsyncable"
        else
          Logger.warn Backup::Errors::GzipRsyncableError.new "System gzip command does not support --rsyncable option - option ignored. A patch may be required for --rsyncable."
        end if @rsyncable
        return opts
      end

    end
  end
end
