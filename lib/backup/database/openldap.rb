# encoding: utf-8

module Backup
  module Database
    class OpenLDAP < Base

      ##
      # Name of the backup file
      attr_accessor :name

      ##
      # Additional "slapcat" options
      attr_accessor :additional_options

      ##
      # Path to the slapcat utility (optional)
      attr_accessor :slapcat_utility

      ##
      # Creates a new instance of the OpenLDAP database object
      def initialize(model, &block)
        super(model)

        @additional_options ||= Array.new

        instance_eval(&block) if block_given?

        @name ||= 'dump'

        @slapcat_utility ||= utility('slapcat')
      end

      ##
      # Performs the slapcat command and outputs the
      # data to the specified path based on the 'trigger'
      def perform!
        super

        dump_ext = 'ldif'
        dump_cmd = "#{ slapcat_utility }"

        if @model.compressor
          @model.compressor.compress_with do |command, ext|
            dump_cmd << " | #{command}"
            dump_ext << ext
          end
        end

        dump_cmd << " > '#{ File.join(@dump_path, name) }.#{ dump_ext }'"
        run(dump_cmd)
      end

      private

      ##
      # Builds a slapcat compatible string for the
      # additional options specified by the user
      def user_options
        @additional_options.join(' ')
      end

    end
  end
end
