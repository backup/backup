# encoding: utf-8

module Backup
  module Database
    class MySQL < Base

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
      # Additional "mysqldump" options
      attr_accessor :additional_options

      ##
      # Path to mysqldump utility (optional)
      attr_accessor :mysqldump_utility

      ##
      # Whether to dump all databases
      attr_accessor :all
      
      ##
      # Creates a new instance of the MySQL adapter object
      def initialize(model, &block)
        super(model)

        @skip_tables        ||= Array.new
        @only_tables        ||= Array.new
        @additional_options ||= Array.new
        @all                ||= false

        instance_eval(&block) if block_given?

        if @utility_path
          Logger.warn "[DEPRECATED] " +
            "Database::MySQL#utility_path has been deprecated.\n" +
            "  Use Database::MySQL#mysqldump_utility instead."
          @mysqldump_utility ||= @utility_path
        end
        @mysqldump_utility ||= utility(:mysqldump)
      end

      ##
      # Performs the mysqldump command and outputs the
      # data to the specified path based on the 'trigger'
      def perform!
        super

        dump_ext = 'sql'
        dump_cmd = "#{ mysqldump }"

        if @model.compressor
          @model.compressor.compress_with do |command, ext|
            dump_cmd << " | #{command}"
            dump_ext << ext
          end
        end

        dump_cmd << " > '#{ File.join(@dump_path, name) }.#{ dump_ext }'"
        run(dump_cmd)
      end

      def name
        all ? 'all' : @name
      end
      
      private

      ##
      # Builds the full mysqldump string based on all attributes
      def mysqldump
        if all # Dump all databases
          "#{ mysqldump_utility } #{ credential_options } #{ connectivity_options } " +
          "#{ user_options } --all-databases"
        else
          "#{ mysqldump_utility } #{ credential_options } #{ connectivity_options } " +
          "#{ user_options } #{ name } #{ tables_to_dump } #{ tables_to_skip }"
        end
      end

      ##
      # Builds the credentials MySQL syntax to authenticate the user
      # to perform the database dumping process
      def credential_options
        %w[username password].map do |option|
          next if send(option).to_s.empty?
          "--#{option}='#{send(option)}'".gsub('--username', '--user')
        end.compact.join(' ')
      end

      ##
      # Builds the MySQL connectivity options syntax to connect the user
      # to perform the database dumping process
      def connectivity_options
        %w[host port socket].map do |option|
          next if send(option).to_s.empty?
          "--#{option}='#{send(option)}'"
        end.compact.join(' ')
      end

      ##
      # Builds a MySQL compatible string for the additional options
      # specified by the user
      def user_options
        additional_options.join(' ')
      end

      ##
      # Builds the MySQL syntax for specifying which tables to dump
      # during the dumping of the database. If the all option is set, ignore.
      def tables_to_dump
        only_tables.join(' ')
      end

      ##
      # Builds the MySQL syntax for specifying which tables to skip
      # during the dumping of the database. If the all option is set, ignore.
      def tables_to_skip
        skip_tables.map do |table|
          "--ignore-table='#{name}.#{table}'"
        end.join(' ')
      end

    end
  end
end
