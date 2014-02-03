# encoding: utf-8

module Backup
  module Database
    class OpenLDAP < Base
      class Error < Backup::Error; end

      ##
      # Name of the backup file
      attr_accessor :name

      ##
      # Additional "slapcat" options
      attr_accessor :additional_options

      ##
      # Connectivity options
      attr_accessor :conf_file

      ##
      # Creates a new instance of the OpenLDAP database object
      def initialize(model, database_id = nil, &block)
        super
        instance_eval(&block) if block_given?

        @name ||= 'ldap'
      end

      ##
      # Performs the slapcat command and outputs the
      # data to the specified path based on the 'trigger'
      def perform!
        super

        pipeline = Pipeline.new
        dump_ext = 'ldif'

        pipeline << slapcat

        model.compressor.compress_with do |command, ext|
          pipeline << command
          dump_ext << ext
        end if model.compressor

        pipeline << "#{ utility(:cat) } > " +
            "'#{ File.join(dump_path, dump_filename) }.#{ dump_ext }'"

        pipeline.run
        if pipeline.success?
          log!(:finished)
        else
          raise Error, "Dump Failed!\n" + pipeline.error_messages
        end
      end

      private

      def slapcat
        "#{ utility(:slapcat) } #{ user_options } " +
        "#{ conf_file_option }"
      end

      def conf_file_option
        "-f #{ conf_file }" if conf_file
      end

      def user_options
        Array(additional_options).join(' ')
      end

    end
  end
end
