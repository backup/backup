# encoding: utf-8

module Backup
  module Database
    class Redis < Base

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
      # Creates a new instance of the Redis database object
      def initialize(&block)
        load_defaults!

        @additional_options ||= Array.new

        instance_eval(&block)
        prepare!
      end

      ##
      # Builds the Redis credentials syntax to authenticate the user
      # to perform the database dumping process
      def credential_options
        return "-a '#{password}'" if password; String.new
      end

      ##
      # Builds the Redis connectivity options syntax to connect the user
      # to perform the database dumping process
      def connectivity_options
        %w[host port socket].map do |option|
          next if send(option).nil?; "-#{option[0,1]} '#{send(option)}'"
        end.compact.join("\s")
      end

      ##
      # Builds a Redis compatible string for the
      # additional options specified by the user
      def additional_options
        @additional_options.join("\s")
      end

      ##
      # Returns the Redis database file name
      def database
        "#{ name }.rdb"
      end

      ##
      # Performs the Redis backup by using the 'cp' unix utility
      # to copy the persisted Redis dump file to the Backup archive.
      # Additionally, when 'invoke_save' is set to true, it'll tell
      # the Redis server to persist the current state to the dump file
      # before copying the dump to get the most recent updates in to the backup
      def perform!
        log!

        invoke_save! if invoke_save
        copy!
      end

      ##
      # Tells Redis to persist the current state of the
      # in-memory database to the persisted dump file
      def invoke_save!
        response = run("#{ utility('redis-cli') } #{ credential_options } #{ connectivity_options } #{ additional_options } SAVE")
        unless response =~ /OK/
          Logger.error "Could not invoke the Redis SAVE command. The #{ database } file might not contain the most recent data."
          Logger.error "Please check if the server is running, the credentials (if any) are correct, and the host/port/socket are correct."
        end
      end

      ##
      # Performs the copy command to copy over the Redis dump file to the Backup archive
      def copy!
        unless File.exist?(File.join(path, database))
          Logger.error "Redis database dump not found in '#{ File.join(path, database) }'"
          exit
        end

        # Temporarily remove a custom `utility_path` setting so that the system
        # `cp` utility can be found, then restore the old value just in case.
        old_path, self.utility_path = self.utility_path, nil
        run("#{ utility(:cp) } '#{ File.join(path, database) }' '#{ File.join(dump_path, database) }'")
        self.utility_path = old_path
      end
    end
  end
end
