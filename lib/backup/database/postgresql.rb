# encoding: utf-8

module Backup
  module Database
    class PostgreSQL < Base
      class Error < Backup::Error; end

      ##
      # Name of the database that needs to get dumped.
      # To dump all databases, set this to `:all` or leave blank.
      # +username+ must be a PostgreSQL superuser to run `pg_dumpall`.
      attr_accessor :name

      ##
      # Credentials for the specified database
      attr_accessor :username, :password

      ##
      # If set the pg_dump(all) command is executed as the given user
      attr_accessor :sudo_user

      ##
      # Connectivity options
      attr_accessor :host, :port, :socket

      ##
      # Tables to skip while dumping the database.
      # If `name` is set to :all (or not specified), these are ignored.
      attr_accessor :skip_tables

      ##
      # Tables to dump. This in only valid if `name` is specified.
      # If none are given, the entire database will be dumped.
      attr_accessor :only_tables

      ##
      # Additional "pg_dump" or "pg_dumpall" options
      attr_accessor :additional_options

      def initialize(model, database_id = nil, &block)
        super
        instance_eval(&block) if block_given?

        @name ||= :all
      end

      ##
      # Performs the mysqldump command and outputs the dump file
      # in the +dump_path+ using +dump_filename+.
      #
      #   <trigger>/databases/PostgreSQL[-<database_id>].sql[.gz]
      def perform!
        super

        pipeline = Pipeline.new
        dump_ext = 'sql'

        pipeline << (dump_all? ? pgdumpall : pgdump)

        model.compressor.compress_with do |command, ext|
          pipeline << command
          dump_ext << ext
        end if model.compressor

        pipeline << "#{ utility(:cat) } > " +
            "'#{ File.join(dump_path, dump_filename) }.#{ dump_ext }'"

        pipeline.run
        if pipeline.success?
          log!(:finished)
        else
          raise Error, "Dump Failed!\n" + pipeline.error_messages
        end
      end

      def pgdump
        "#{ password_option }" +
        "#{ sudo_option }" +
        "#{ utility(:pg_dump) } #{ username_option } #{ connectivity_options } " +
        "#{ user_options } #{ tables_to_dump } #{ tables_to_skip } #{ name }"
      end

      def pgdumpall
        "#{ password_option }" +
        "#{ sudo_option }" +
        "#{ utility(:pg_dumpall) } #{ username_option } " +
        "#{ connectivity_options } #{ user_options }"
      end

      def password_option
        "PGPASSWORD='#{ password }' " if password
      end

      def sudo_option
        "#{ utility(:sudo) } -n -u #{ sudo_user } " if sudo_user
      end

      def username_option
        "--username='#{ username }'" if username
      end

      def connectivity_options
        return "--host='#{ socket }'" if socket

        opts = []
        opts << "--host='#{ host }'" if host
        opts << "--port='#{ port }'" if port
        opts.join(' ')
      end

      def user_options
        Array(additional_options).join(' ')
      end

      def tables_to_dump
        Array(only_tables).map do |table|
          "--table='#{ table }'"
        end.join(' ')
      end

      def tables_to_skip
        Array(skip_tables).map do |table|
          "--exclude-table='#{ table }'"
        end.join(' ')
      end

      def dump_all?
        name == :all
      end

      attr_deprecate :utility_path, :version => '3.0.21',
          :message => 'Use Backup::Utilities.configure instead.',
          :action => lambda {|klass, val|
            Utilities.configure { pg_dump val }
          }

      attr_deprecate :pg_dump_utility, :version => '3.3.0',
          :message => 'Use Backup::Utilities.configure instead.',
          :action => lambda {|klass, val|
            Utilities.configure { pg_dump val }
          }

    end
  end
end
