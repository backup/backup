# encoding: utf-8

module Backup
  module Configuration
    module Database
      class PostgreSQL < Base
        class << self

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

        end
      end
    end
  end
end
