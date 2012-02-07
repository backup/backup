# encoding: utf-8

module Backup
  module Database
    class MySQL < Base

      ##
      # Name of the database that needs to get dumped
      # To dump all databases, set this to `:all` or leave blank.
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
      # Creates a new instance of the MySQL adapter object
      def initialize(model, &block)
        super(model)

        @skip_tables        ||= Array.new
        @only_tables        ||= Array.new
        @additional_options ||= Array.new

        instance_eval(&block) if block_given?

        @name ||= :all

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

        dump_cmd << " > '#{ File.join(@dump_path, dump_filename) }.#{ dump_ext }'"
        run(dump_cmd)
      end

      private

      ##
      # Builds the full mysqldump string based on all attributes
      def mysqldump
        "#{ mysqldump_utility } #{ credential_options } #{ connectivity_options } " +
        "#{ user_options } #{ db_name } #{ tables_to_dump } #{ tables_to_skip }"
      end

      ##
      # Returns the filename to use for dumping the database(s)
      def dump_filename
        dump_all? ? 'all-databases' : name
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
      # Returns the database name to use in the mysqldump command.
      # When dumping all databases, the database name is replaced
      # with the command option to dump all databases.
      def db_name
        dump_all? ? '--all-databases' : name
      end

      ##
      # Builds the MySQL syntax for specifying which tables to dump
      # during the dumping of the database
      def tables_to_dump
        only_tables.join(' ') unless dump_all?
      end

      ##
      # Builds the MySQL syntax for specifying which tables to skip
      # during the dumping of the database
      def tables_to_skip
        skip_tables.map do |table|
          "--ignore-table='#{name}.#{table}'"
        end.join(' ') unless dump_all?
      end

      ##
      # Return true if we're dumping all databases.
      # `name` will be set to :all if it is not set,
      # so this will be true by default
      def dump_all?
        name == :all
      end

    end
  end
end
