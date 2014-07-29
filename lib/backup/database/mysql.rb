# encoding: utf-8
require 'shellwords'

module Backup
  module Database
    class MySQL < Base
      class Error < Backup::Error; end

      ##
      # Name of the database that needs to get dumped
      # To dump all databases, set this to `:all` or leave blank.
      attr_accessor :name

      ##
      # Credentials for the specified database
      attr_accessor :username, :password

      ##
      # Connectivity options
      attr_accessor :host, :port, :socket

      ##
      # Tables to skip while dumping the database
      #
      # If `name` is set to :all (or not specified), these must include
      # a database name. e.g. 'name.table'.
      # If `name` is given, these may simply be table names.
      attr_accessor :skip_tables

      ##
      # Tables to dump. This in only valid if `name` is specified.
      # If none are given, the entire database will be dumped.
      attr_accessor :only_tables

      ##
      # Additional "mysqldump" or "innobackupex (backup creation)" options
      attr_accessor :additional_options

      ##
      # Additional innobackupex log preparation phase ("apply-logs") options
      attr_accessor :prepare_options

      ##
      # Default is :mysqldump (which is built in MySQL and generates
      # a textual SQL file), but can be changed to :innobackupex, which
      # has more feasible restore times for large databases.
      # See: http://www.percona.com/doc/percona-xtrabackup/
      attr_accessor :backup_engine

      ##
      # If set the backup engine command block is executed as the given user
      attr_accessor :sudo_user

      ##
      # If set, do not suppress innobackupdb output (useful for debugging)
      attr_accessor :verbose

      def initialize(model, database_id = nil, &block)
        super
        instance_eval(&block) if block_given?

        @name ||= :all
        @backup_engine ||= :mysqldump
      end

      ##
      # Performs the mysqldump or innobackupex command and outputs
      # the dump file in the +dump_path+ using +dump_filename+.
      #
      #   <trigger>/databases/MySQL[-<database_id>].[sql|tar][.gz]
      def perform!
        super

        pipeline = Pipeline.new
        dump_ext = sql_backup? ? 'sql' : 'tar'

        pipeline << sudo_option(sql_backup? ? mysqldump : innobackupex)

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

      private

      def mysqldump
        "#{ utility(:mysqldump) } #{ credential_options } " +
        "#{ connectivity_options } #{ user_options } #{ name_option } " +
        "#{ tables_to_dump } #{ tables_to_skip }"
      end

      def credential_options
        opts = []
        opts << "--user=#{ Shellwords.escape(username) }" if username
        opts << "--password=#{ Shellwords.escape(password) }" if password
        opts.join(' ')
      end

      def connectivity_options
        return "--socket='#{ socket }'" if socket

        opts = []
        opts << "--host='#{ host }'" if host
        opts << "--port='#{ port }'" if port
        opts.join(' ')
      end

      def user_options
        Array(additional_options).join(' ')
      end

      def user_prepare_options
        Array(prepare_options).join(' ')
      end

      def name_option
        dump_all? ? '--all-databases' : name
      end

      def tables_to_dump
        Array(only_tables).join(' ') unless dump_all?
      end

      def tables_to_skip
        Array(skip_tables).map do |table|
          table = (dump_all? || table['.']) ? table : "#{ name }.#{ table }"
          "--ignore-table='#{ table }'"
        end.join(' ')
      end

      def dump_all?
        name == :all
      end

      def sql_backup?
        backup_engine.to_sym == :mysqldump
      end

      def innobackupex
        # Creation phase
        "#{ utility(:innobackupex) } #{ credential_options } " +
        "#{ connectivity_options } #{ user_options } " +
        "--no-timestamp #{ temp_dir } #{ quiet_option } && " +
        # Log applying phase (prepare for restore)
        "#{ utility(:innobackupex) } --apply-log #{ temp_dir } " +
        "#{ user_prepare_options }  #{ quiet_option } && " +
        # Move files to tar-ed stream on stdout
        "#{ utility(:tar) } --remove-files -cf -  " +
        "-C #{ File.dirname(temp_dir) } #{ File.basename(temp_dir) }"
      end

      def sudo_option(command_block)
        return command_block unless sudo_user

        "sudo -s -u #{ sudo_user } -- <<END_OF_SUDO\n" +
        "#{command_block}\n" +
        "END_OF_SUDO\n"
      end

      def quiet_option
        verbose ? "" : " 2> /dev/null "
      end

      def temp_dir
        File.join(dump_path, dump_filename + ".bkpdir")
      end

    end
  end
end
