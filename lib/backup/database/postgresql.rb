# encoding: utf-8

module Backup
  module Database
    class PostgreSQL < Base

      ##
      # Name of the database that needs to get dumped
      attr_accessor :name

      ##
      # Credentials for the specified database
      attr_accessor :username, :password

      ##
      # Connectivity options
      attr_accessor :host, :port, :socket

      ##
      # Tables to skip while dumping the database
      attr_accessor :skip_tables

      ##
      # Tables to dump, tables that aren't specified won't get dumped
      attr_accessor :only_tables

      ##
      # Additional "pg_dump" options
      attr_accessor :additional_options

      ##
      # Path to pg_dump utility (optional)
      attr_accessor :pg_dump_utility

      def initialize(model, database_id = nil, &block)
        super
        instance_eval(&block) if block_given?

        @pg_dump_utility ||= utility(:pg_dump)
      end

      ##
      # Performs the mysqldump command and outputs the dump file
      # in the +dump_path+ using +dump_filename+.
      #
      #   <trigger>/databases/PostgreSQL[-<database_id>].sql[.gz]
      def perform!
        super

        pipeline = Pipeline.new
        dump_ext = 'sql'

        pipeline << pgdump

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
          raise Errors::Database::PipelineError,
              "#{ database_name } Dump Failed!\n" + pipeline.error_messages
        end
      end

      def pgdump
        "#{ password_option }" +
        "#{ pg_dump_utility } #{ username_option } #{ connectivity_options } " +
        "#{ user_options } #{ tables_to_dump } #{ tables_to_skip } #{ name }"
      end

      def password_option
        "PGPASSWORD='#{ password }' " if password
      end

      def username_option
        "--username='#{ username }'" if username
      end

      def connectivity_options
        return "--host='#{ socket }'" if socket

        opts = []
        opts << "--host='#{ host }'" if host
        opts << "--port='#{ port }'" if port
        opts.join(' ')
      end

      def user_options
        Array(additional_options).join(' ')
      end

      def tables_to_dump
        Array(only_tables).map do |table|
          "--table='#{ table }'"
        end.join(' ')
      end

      def tables_to_skip
        Array(skip_tables).map do |table|
          "--exclude-table='#{ table }'"
        end.join(' ')
      end

      attr_deprecate :utility_path, :version => '3.0.21',
          :message => 'Use PostgreSQL#pg_dump_utility instead.',
          :action => lambda {|klass, val| klass.pg_dump_utility = val }

    end
  end
end
