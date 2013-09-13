# encoding: utf-8

module Backup
  module Compressor
    class Gzip < Base
      class Error < Backup::Error; end
      extend Utilities::Helpers

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
      # Use the `--rsyncable` option with `gzip`.
      #
      # This option directs `gzip` to compress data using an algorithm that
      # allows `rsync` to efficiently detect changes. This is especially useful
      # when used to compress `Archive` or `Database` backups that will be
      # stored using Backup's `RSync` Storage option.
      #
      # The `--rsyncable` option is only available on patched versions of `gzip`.
      # While most distributions apply this patch, this option may not be
      # available on your system. If it's not available, Backup will log a
      # warning and continue to use the compressor without this option.
      attr_accessor :rsyncable

      ##
      # Determine if +--rsyncable+ is supported and cache the result.
      def self.has_rsyncable?
        return @has_rsyncable unless @has_rsyncable.nil?
        cmd = "#{ utility(:gzip) } --rsyncable --version >/dev/null 2>&1; echo $?"
        @has_rsyncable = %x[#{ cmd }].chomp == '0'
      end

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

      private

      def options
        opts = ''
        opts << " -#{ @level }" if @level
        if self.class.has_rsyncable?
          opts << ' --rsyncable'
        else
          Logger.warn Error.new(<<-EOS)
            'rsyncable' option ignored.
            Your system's 'gzip' does not support the `--rsyncable` option.
          EOS
        end if @rsyncable
        opts
      end

    end
  end
end
