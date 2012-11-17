# encoding: utf-8

module Backup
  module Database
    class MongoDB < Base

      ##
      # Name of the database that needs to get dumped
      attr_accessor :name

      ##
      # Credentials for the specified database
      attr_accessor :username, :password

      ##
      # Connectivity options
      attr_accessor :host, :port

      ##
      # IPv6 support (disabled by default)
      attr_accessor :ipv6

      ##
      # Collections to dump, collections that aren't specified won't get dumped
      attr_accessor :only_collections

      ##
      # Additional "mongodump" options
      attr_accessor :additional_options

      ##
      # Path to the mongodump utility (optional)
      attr_accessor :mongodump_utility

      attr_deprecate :utility_path, :version => '3.0.21',
          :message => 'Use MongoDB#mongodump_utility instead.',
          :action => lambda {|klass, val| klass.mongodump_utility = val }

      ##
      # Path to the mongo utility (optional)
      attr_accessor :mongo_utility

      ##
      # 'lock' dump meaning wrapping mongodump with fsync & lock
      attr_accessor :lock

      ##
      # Creates a new instance of the MongoDB database object
      def initialize(model, &block)
        super(model)

        @only_collections   ||= Array.new
        @additional_options ||= Array.new
        @ipv6               ||= false
        @lock               ||= false

        instance_eval(&block) if block_given?

        @mongodump_utility  ||= utility(:mongodump)
        @mongo_utility      ||= utility(:mongo)
      end

      ##
      # Performs the mongodump command and outputs the data to the
      # specified path based on the 'trigger'. If the user hasn't specified any
      # specific collections to dump, it'll dump everything. If the user has specified
      # collections to dump, it'll loop through the array of collections and invoke the
      # 'mongodump' command once per collection
      def perform!
        super

        lock_database if @lock
        @only_collections.empty? ? dump! : specific_collection_dump!

      rescue => err
        raise Errors::Database::MongoDBError.wrap(err, 'Database Dump Failed!')
      ensure
        unlock_database if @lock
        package! unless err
      end

      private

      ##
      # Builds and runs the mongodump command
      def dump!
        run(mongodump)
      end

      ##
      # For each collection in the @only_collections array, it'll
      # build the whole 'mongodump' command, append the '--collection' option,
      # and run the command built command
      def specific_collection_dump!
        @only_collections.each do |collection|
          run("#{mongodump} --collection='#{collection}'")
        end
      end

      ##
      # Builds the full mongodump string based on all attributes
      def mongodump
        "#{ mongodump_utility } #{ database } #{ credential_options } " +
        "#{ connectivity_options } #{ ipv6_option } #{ user_options } #{ dump_directory }"
      end

      ##
      # If a compressor is configured, packages the dump_path into a
      # single compressed tar archive, then removes the dump_path.
      # e.g.
      #   if the database was dumped to:
      #     ~/Backup/.tmp/databases/MongoDB/
      #   then it will be packaged into:
      #     ~/Backup/.tmp/databases/MongoDB-<timestamp>.tar.gz
      def package!
        return unless @model.compressor

        pipeline  = Pipeline.new
        base_dir  = File.dirname(@dump_path)
        dump_dir  = File.basename(@dump_path)
        timestamp = Time.now.to_i.to_s[-5, 5]
        outfile   = @dump_path + '-' + timestamp + '.tar'

        Logger.message(
          "#{ database_name } started compressing and packaging:\n" +
          "  '#{ @dump_path }'"
        )

        pipeline << "#{ utility(:tar) } -cf - -C '#{ base_dir }' '#{ dump_dir }'"
        @model.compressor.compress_with do |command, ext|
          pipeline << command
          outfile << ext
        end
        pipeline << "cat > #{ outfile }"

        pipeline.run
        if pipeline.success?
          Logger.message(
            "#{ database_name } completed compressing and packaging:\n" +
            "  '#{ outfile }'"
          )
          FileUtils.rm_rf(@dump_path)
        else
          raise Errors::Database::PipelineError,
            "#{ database_name } Failed to create compressed dump package:\n" +
            "'#{ outfile }'\n" +
            pipeline.error_messages
        end
      end

      ##
      # Returns the MongoDB database selector syntax
      def database
        "--db='#{ name }'" if name
      end

      ##
      # Builds the MongoDB credentials syntax to authenticate the user
      # to perform the database dumping process
      def credential_options
        %w[username password].map do |option|
          next if send(option).to_s.empty?
          "--#{option}='#{send(option)}'"
        end.compact.join(' ')
      end

      ##
      # Builds the MongoDB connectivity options syntax to connect the user
      # to perform the database dumping process
      def connectivity_options
        %w[host port].map do |option|
          next if send(option).to_s.empty?
          "--#{option}='#{send(option)}'"
        end.compact.join(' ')
      end

      ##
      # Returns the mongodump syntax for enabling ipv6
      def ipv6_option
        @ipv6 ? '--ipv6' : ''
      end

      ##
      # Builds a MongoDB compatible string for the
      # additional options specified by the user
      def user_options
        @additional_options.join(' ')
      end

      ##
      # Returns the MongoDB syntax for determining where to output all the database dumps,
      # e.g. ~/Backup/.tmp/databases/MongoDB/<databases here>/<database collections>
      def dump_directory
        "--out='#{ @dump_path }'"
      end

      ##
      # Locks and FSyncs the database to bring it up to sync
      # and ensure no 'write operations' are performed during the
      # dump process
      def lock_database
        lock_command = <<-EOS.gsub(/^ +/, ' ')
          echo 'use admin
          db.runCommand({"fsync" : 1, "lock" : 1})' | #{ "#{ mongo_utility } #{ mongo_uri }" }
        EOS

        run(lock_command)
      end

      ##
      # Unlocks the (locked) database
      def unlock_database
        unlock_command = <<-EOS.gsub(/^ +/, ' ')
          echo 'use admin
          db.$cmd.sys.unlock.findOne()' | #{ "#{ mongo_utility } #{ mongo_uri }" }
        EOS

        run(unlock_command)
      end

      ##
      # Builds a Mongo URI based on the provided attributes
      def mongo_uri
        ["#{ host }:#{ port }#{ ('/' + name) if name }",
         credential_options, ipv6_option].join(' ').strip
      end

    end
  end
end
