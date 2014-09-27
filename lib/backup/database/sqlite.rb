# encoding: utf-8

module Backup
  module Database
    class SQLite < Base
      class Error < Backup::Error; end

      ##
      # Path to the sqlite3 file
      attr_accessor :path

      ##
      # Path to sqlite utility (optional)
      attr_accessor :sqlitedump_utility

      ##
      # Creates a new instance of the SQLite adapter object
      def initialize(model, database_id = nil, &block)
        super
        instance_eval(&block) if block_given?

        @sqlitedump_utility ||= utility(:sqlitedump)
      end

      ##
      # Performs the sqlitedump command and outputs the
      # data to the specified path based on the 'trigger'
      def perform!
        super

        dump = "echo '.dump' | #{ sqlitedump_utility } #{ path }"

        pipeline = Pipeline.new
        dump_ext = 'sql'

        pipeline << dump
        if model.compressor
          model.compressor.compress_with do |command, ext|
            pipeline << command
            dump_ext << ext
          end
        end

        pipeline << "cat > '#{ File.join( dump_path , dump_filename) }.#{ dump_ext }'"

        pipeline.run

        if pipeline.success?
          log!(:finished)
        else
          raise Error,
            "#{ database_name } Dump Failed!\n" + pipeline.error_messages
        end
      end
    end
  end
end
