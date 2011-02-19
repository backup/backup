# encoding: utf-8

module Backup
  module Adapter
    class MySQL

      ##
      # Name of the database that needs to get dumped
      attr_accessor :database

      ##
      # Credentials for the specified database
      attr_accessor :user, :password

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
        @skip_tables        = Array.new
        @only_tables        = Array.new
        @additional_options = Array.new

        instance_eval(&block)
      end

    end
  end
end
