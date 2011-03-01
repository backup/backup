# encoding: utf-8

module Backup
  module Database
    class PostgreSQL < Base

      ##
      # Name of the database that needs to get dumped
      attr_accessor :name

      ##
      # Credentials for the specified database
      attr_accessor :user, :password

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
      # Creates a new instance of the PostgreSQL adapter object
      # Sets the PGPASSWORD environment variable to the password
      # so it doesn't prompt and hang in the process
      def initialize(&block)
        @skip_tables        = Array.new
        @only_tables        = Array.new
        @additional_options = Array.new

        instance_eval(&block)
        prepare!
        ENV['PGPASSWORD'] = password
      end

      ##
      # Builds the PostgreSQL syntax for specifying which tables to skip
      # during the dumping of the database
      def tables_to_skip
        skip_tables.map do |table|
          "--exclude-table='#{table}'"
        end.join("\s")
      end

      ##
      # Builds the PostgreSQL syntax for specifying which tables to dump
      # during the dumping of the database
      def tables_to_dump
        only_tables.map do |table|
          "--table='#{table}'"
        end.join("\s")
      end

      ##
      # Builds the credentials PostgreSQL syntax to authenticate the user
      # to perform the database dumping process
      def credential_options
        "--username='#{user}'"
      end

      ##
      # Builds the PostgreSQL connectivity options syntax to connect the user
      # to perform the database dumping process, socket gets gsub'd to host since
      # that's the option PostgreSQL takes for socket connections as well. In case
      # both the host and the socket are specified, the socket will take priority over the host
      def connectivity_options
        %w[host port socket].map do |option|
          next if send(option).nil? or send(option).empty?
          "--#{option}='#{send(option)}'".gsub('--socket=', '--host=')
        end.compact.join("\s")
      end

      ##
      # Builds a PostgreSQL compatible string for the additional options
      # specified by the user
      def options
        additional_options.join("\s")
      end

      ##
      # Builds the full pgdump string based on all attributes
      def pgdump
        "#{ utility(:pg_dump) } #{ credential_options } #{ connectivity_options } " +
        "#{ options } #{ tables_to_dump } #{ tables_to_skip } #{ name }"
      end

      ##
      # Performs the pgdump command and outputs the
      # data to the specified path based on the 'trigger'
      def perform!
        log!
        run("#{pgdump} > '#{File.join(dump_path, name)}.sql'")
        ENV['PGPASSWORD'] = nil
      end

    end
  end
end
