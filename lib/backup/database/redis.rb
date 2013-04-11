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
      # Connectivity options
      attr_accessor :host, :port, :socket

      ##
      # Determines whether Backup should invoke the SAVE command through
      # the 'redis-cli' utility to persist the most recent data before
      # copying over the dump file
      attr_accessor :invoke_save

      ##
      # Additional "redis-cli" options
      attr_accessor :additional_options

      ##
      # Path to the redis-cli utility (optional)
      attr_accessor :redis_cli_utility

      attr_deprecate :utility_path, :version => '3.0.21',
          :message => 'Use Redis#redis_cli_utility instead.',
          :action => lambda {|klass, val| klass.redis_cli_utility = val }

      ##
      # Creates a new instance of the Redis database object
      def initialize(model, &block)
        super(model)

        @additional_options ||= Array.new

        instance_eval(&block) if block_given?

        @name ||= 'dump'
        @redis_cli_utility ||= utility('redis-cli')
      end

      ##
      # Performs the Redis backup by using the 'cp' unix utility
      # to copy the persisted Redis dump file to the Backup archive.
      # Additionally, when 'invoke_save' is set to true, it'll tell
      # the Redis server to persist the current state to the dump file
      # before copying the dump to get the most recent updates in to the backup
      def perform!
        super

        invoke_save! if invoke_save
        copy!
      end

      private

      ##
      # Tells Redis to persist the current state of the
      # in-memory database to the persisted dump file
      def invoke_save!
        response = run("#{ redis_cli_utility } #{ credential_options } " +
                       "#{ connectivity_options } #{ user_options } SAVE")
        unless response =~ /OK/
          raise Errors::Database::Redis::CommandError, <<-EOS
            Could not invoke the Redis SAVE command.
            The #{ database } file might not contain the most recent data.
            Please check if the server is running, the credentials (if any) are correct,
            and the host/port/socket are correct.

            Redis CLI response: #{ response }
          EOS
        end
      end

      ##
      # Performs the copy command to copy over the Redis dump file to the Backup archive
      def copy!
        src_path = File.join(path, database)
        unless File.exist?(src_path)
          raise Errors::Database::Redis::NotFoundError, <<-EOS
            Redis database dump not found
            File path was #{ src_path }
          EOS
        end

        dst_path = File.join(@dump_path, database)
        if @model.compressor
          @model.compressor.compress_with do |command, ext|
            run("#{ command } -c #{ src_path } > #{ dst_path + ext }")
          end
        else
          FileUtils.cp(src_path, dst_path)
        end
      end

      ##
      # Returns the Redis database file name
      def database
        "#{ name }.rdb"
      end

      ##
      # Builds the Redis credentials syntax to authenticate the user
      # to perform the database dumping process
      def credential_options
        password.to_s.empty? ? '' : "-a '#{password}'"
      end

      ##
      # Builds the Redis connectivity options syntax to connect the user
      # to perform the database dumping process
      def connectivity_options
        %w[host port socket].map do |option|
          next if send(option).to_s.empty?
          "-#{option[0,1]} '#{send(option)}'"
        end.compact.join(' ')
      end

      ##
      # Builds a Redis compatible string for the
      # additional options specified by the user
      def user_options
        @additional_options.join(' ')
      end

    end
  end
end
