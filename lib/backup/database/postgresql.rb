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

      attr_deprecate :utility_path, :version => '3.0.21',
          :message => 'Use PostgreSQL#pg_dump_utility instead.',
          :action => lambda {|klass, val| klass.pg_dump_utility = val }

      ##
      # Creates a new instance of the PostgreSQL adapter object
      # Sets the PGPASSWORD environment variable to the password
      # so it doesn't prompt and hang in the process
      def initialize(model, &block)
        super(model)

        @skip_tables        ||= Array.new
        @only_tables        ||= Array.new
        @additional_options ||= Array.new

        instance_eval(&block) if block_given?

        @pg_dump_utility ||= utility(:pg_dump)
      end

      ##
      # Performs the pgdump command and outputs the
      # data to the specified path based on the 'trigger'
      def perform!
        super

        pipeline = Pipeline.new
        dump_ext = 'sql'

        pipeline << pgdump
        if @model.compressor
          @model.compressor.compress_with do |command, ext|
            pipeline << command
            dump_ext << ext
          end
        end
        pipeline << "cat > '#{ File.join(@dump_path, name) }.#{ dump_ext }'"

        pipeline.run
        if pipeline.success?
          Logger.message "#{ database_name } Complete!"
        else
          raise Errors::Database::PipelineError,
              "#{ database_name } Dump Failed!\n" +
              pipeline.error_messages
        end
      end

      ##
      # Builds the full pgdump string based on all attributes
      def pgdump
        "#{password_options}" +
        "#{ pg_dump_utility } #{ username_options } #{ connectivity_options } " +
        "#{ user_options } #{ tables_to_dump } #{ tables_to_skip } #{ name }"
      end

      ##
      # Builds the password syntax PostgreSQL uses to authenticate the user
      # to perform database dumping
      def password_options
        password.to_s.empty? ? '' : "PGPASSWORD='#{password}' "
      end

      ##
      # Builds the credentials PostgreSQL syntax to authenticate the user
      # to perform the database dumping process
      def username_options
        username.to_s.empty? ? '' : "--username='#{username}'"
      end

      ##
      # Builds the PostgreSQL connectivity options syntax to connect the user
      # to perform the database dumping process, socket gets gsub'd to host since
      # that's the option PostgreSQL takes for socket connections as well. In case
      # both the host and the socket are specified, the socket will take priority over the host
      def connectivity_options
        %w[host port socket].map do |option|
          next if send(option).to_s.empty?
          "--#{option}='#{send(option)}'".gsub('--socket=', '--host=')
        end.compact.join(' ')
      end

      ##
      # Builds a PostgreSQL compatible string for the additional options
      # specified by the user
      def user_options
        additional_options.join(' ')
      end

      ##
      # Builds the PostgreSQL syntax for specifying which tables to dump
      # during the dumping of the database
      def tables_to_dump
        only_tables.map do |table|
          "--table='#{table}'"
        end.join(' ')
      end

      ##
      # Builds the PostgreSQL syntax for specifying which tables to skip
      # during the dumping of the database
      def tables_to_skip
        skip_tables.map do |table|
          "--exclude-table='#{table}'"
        end.join(' ')
      end

    end
  end
end
