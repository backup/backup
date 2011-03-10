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
      # Creates a new instance of the MySQL adapter object
      def initialize(&block)
        load_defaults!

        @skip_tables        ||= Array.new
        @only_tables        ||= Array.new
        @additional_options ||= Array.new

        instance_eval(&block)
        prepare!
      end

      ##
      # Builds the MySQL syntax for specifying which tables to skip
      # during the dumping of the database
      def tables_to_skip
        skip_tables.map do |table|
          "--ignore-table='#{name}.#{table}'"
        end.join("\s")
      end

      ##
      # Builds the MySQL syntax for specifying which tables to dump
      # during the dumping of the database
      def tables_to_dump
        only_tables.join("\s")
      end

      ##
      # Builds the credentials MySQL syntax to authenticate the user
      # to perform the database dumping process
      def credential_options
        %w[username password].map do |option|
          next if send(option).nil? or send(option).empty?
          "--#{option}='#{send(option)}'".gsub('--username', '--user')
        end.compact.join("\s")
      end

      ##
      # Builds the MySQL connectivity options syntax to connect the user
      # to perform the database dumping process
      def connectivity_options
        %w[host port socket].map do |option|
          next if send(option).nil? or (send(option).respond_to?(:empty?) and send(option).empty?)
          "--#{option}='#{send(option)}'"
        end.compact.join("\s")
      end

      ##
      # Builds a MySQL compatible string for the additional options
      # specified by the user
      def options
        additional_options.join("\s")
      end

      ##
      # Builds the full mysqldump string based on all attributes
      def mysqldump
        "#{ utility(:mysqldump) } #{ credential_options } #{ connectivity_options } " +
        "#{ options } #{ name } #{ tables_to_dump } #{ tables_to_skip }"
      end

      ##
      # Performs the mysqldump command and outputs the
      # data to the specified path based on the 'trigger'
      def perform!
        log!
        run("#{mysqldump} > '#{File.join(dump_path, name)}.sql'")
      end

    end
  end
end
