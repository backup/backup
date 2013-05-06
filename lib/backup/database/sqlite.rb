# encoding: utf-8

module Backup
  module Database
    class SQLite < Base

      ##
      # Name of the database that needs to get dumped
      attr_accessor :name

      # path option
      attr_accessor :path
      
      ##
      # Path to sqlite utility (optional)
                     
      attr_accessor :sqlitedump_utility

      attr_deprecate :utility_path, :version => '3.7.14.1',
          :message => 'Use SQLite#sqlitedump_utility instead.',
          :action => lambda {|klass, val| klass.sqlitedump_utility = val }

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
        i = 0

        sqlitedump.each do |eachsqlitedump|
          pipeline = Pipeline.new
          dump_ext = 'sql'
          
          pipeline << eachsqlitedump
          if @model.compressor
            @model.compressor.compress_with do |command, ext|
              pipeline << command
              dump_ext << ext
            end
          end
          #dump_filename = \/[\w\dß._-]+\.sqlite3$/.match(sqlitedump.chars.normalize(:kd).gsub(/[^\x00-\x7F]/n,''))
          #dump_filename = /\/[\w\däöüÄÖÜßéÉèÈóÓòÒáÁàÀß\._-]+\.sqlite3$/.match(sqlitedump.downcase).to_s[1,sqlitedump.downcase.length]
          dump_filename = db_name[i]
          pipeline << "cat > '#{ File.join(@dump_path, dump_filename) }.#{ dump_ext }'"
          
          pipeline.run
          if pipeline.success?
            log!(:finished)
          else
            raise Errors::Database::PipelineError,
                "#{ database_name } Dump Failed!\n" + pipeline.error_messages
          end
          i += 1
        end
      end

      private

      ##
      # Builds the full SQLite dump string based on all attributes
      def sqlitedump
        db_name.map{|n| "echo '.dump' | #{ sqlitedump_utility } #{ db_path }#{ n }" }
      end

      ##
      # Returns the database path and adds a / at the end if not present
      def db_path
        #todo: deal with windows where / might be \
        if path.length>=1 && path[-1, 1]!="/"
          "#{path}/"
        else
          path
        end
      end
      
      ##
      # Returns the database name to use in the SQLite dump command.
      # When dumping all databases, the database name is replaced
      # with the command option to dump all databases.
      def db_name
        if @all_dbs.nil?
          @all_dbs = Dir.new(path).entries.reject {|f| [".", ".."].include? f}.select{|f| /.*.sqlite3$/.match(f)}
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
