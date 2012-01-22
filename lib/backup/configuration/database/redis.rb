# encoding: utf-8

module Backup
  module Configuration
    module Database
      class Redis < Base
        class << self

          ##
          # Name of and path to the database that needs to get dumped
          attr_accessor :name, :path

          ##
          # Credentials for the specified database
          attr_accessor :password

          ##
          # Determines whether Backup should invoke the SAVE command through
          # the 'redis-cli' utility to persist the most recent data before
          # copying over the dump file
          attr_accessor :invoke_save

          ##
          # Connectivity options
          attr_accessor :host, :port, :socket

          ##
          # Additional "redis-cli" options
          attr_accessor :additional_options

          ##
          # Path to the redis-cli utility (optional)
          attr_accessor :redis_cli_utility

        end
      end
    end
  end
end
