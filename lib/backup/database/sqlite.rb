# encoding: utf-8

module Backup
  module Database
    class SQLite < Base
      class Error < Backup::Error; end

      ##
      # Name of the database that needs to get dumped
      attr_accessor :name

      # path option
      attr_accessor :path

      ##
      # Path to sqlite utility (optional)
      attr_accessor :sqlitedump_utility

      ##
      # Creates a new instance of the SQLite adapter object
      def initialize(model, database_id = nil, &block)
        super
        instance_eval(&block) if block_given?

        @name ||= :all
        @sqlitedump_utility ||= utility(:sqlitedump)
      end

      ##
      # Performs the sqlitedump command and outputs the
      # data to the specified path based on the 'trigger'
      def perform!
        super

        dumps = sqlitedump
        db_name_list = db_names

        dumps.each_with_index do |dump, i|
          pipeline = Pipeline.new
          dump_ext = 'sql'

          pipeline << dump
          if @model.compressor
            @model.compressor.compress_with do |command, ext|
              pipeline << command
              dump_ext << ext
            end
          end

          dump_filename = db_name_list[i]
          pipeline << "cat > '#{ File.join(@dump_path, dump_filename) }.#{ dump_ext }'"

          pipeline.run

          if pipeline.success?
            log!(:finished)
          else
            raise Error,
              "#{ database_name } Dump Failed!\n" + pipeline.error_messages
          end

          i += 1
        end
      end

      private

      ##
      # Builds the full SQLite dump string based on all attributes
      def sqlitedump
        db_names.map { |n| "echo '.dump' | #{ sqlitedump_utility } #{ db_path }#{ n }" }
      end

      ##
      # Returns the database path and adds a / at the end if not present
      def db_path
        if path.length >= 1 && path[-1, 1] != "/"
          "#{path}/"
        else
          path
        end
      end

      ##
      # Returns the database names to use in the SQLite dump command.
      def db_names
        if @all_dbs.nil?
          @all_dbs = Dir.new(path).entries.select{|f| /.*.sqlite3$/.match(f)}
        end
        dump_all? ? @all_dbs : Array(name)
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
