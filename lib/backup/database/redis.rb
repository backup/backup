# encoding: utf-8

module Backup
  module Database
    class Redis < Base
      class Error < Backup::Error; end

      MODES = [:copy, :sync]

      ##
      # Mode of operation.
      #
      # [:copy]
      #   Copies the redis dump file specified by {#rdb_path}.
      #   This data will be current as of the last RDB Snapshot
      #   performed by the server (per your redis.conf settings).
      #   You may set {#invoke_save} to +true+ to have Backup issue
      #   a +SAVE+ command to update the dump file with the current
      #   data before performing the copy.
      #
      # [:sync]
      #   Performs a dump of your redis data using +redis-cli --rdb -+.
      #   Redis implements this internally using a +SYNC+ command.
      #   The operation is analogous to requesting a +BGSAVE+, then having the
      #   dump returned. This mode is capable of dumping data from a local or
      #   remote server. Requires Redis v2.6 or better.
      #
      # Defaults to +:copy+.
      attr_accessor :mode

      ##
      # Full path to the redis dump file.
      #
      # Required when {#mode} is +:copy+.
      attr_accessor :rdb_path

      ##
      # Perform a +SAVE+ command using the +redis-cli+ utility
      # before copying the dump file specified by {#rdb_path}.
      #
      # Only valid when {#mode} is +:copy+.
      attr_accessor :invoke_save

      ##
      # Connectivity options for the +redis-cli+ utility.
      attr_accessor :host, :port, :socket

      ##
      # Password for the +redis-cli+ utility.
      attr_accessor :password

      ##
      # Additional options for the +redis-cli+ utility.
      attr_accessor :additional_options

      def initialize(model, database_id = nil, &block)
        super
        instance_eval(&block) if block_given?

        @mode ||= :copy

        unless MODES.include?(mode)
          raise Error, "'#{ mode }' is not a valid mode"
        end

        if mode == :copy && rdb_path.nil?
          raise Error, '`rdb_path` must be set when `mode` is :copy'
        end
      end

      ##
      # Performs the dump based on {#mode} and stores the Redis dump file
      # to the +dump_path+ using the +dump_filename+.
      #
      #   <trigger>/databases/Redis[-<database_id>].rdb[.gz]
      def perform!
        super

        case mode
        when :sync
          # messages output by `redis-cli --rdb` on $stderr
          Logger.configure do
            ignore_warning(/Transfer finished with success/)
            ignore_warning(/SYNC sent to master/)
          end
          sync!
        when :copy
          save! if invoke_save
          copy!
        end

        log!(:finished)
      end

      private

      def sync!
        pipeline = Pipeline.new
        dump_ext = 'rdb'

        pipeline << "#{ redis_cli_cmd } --rdb -"

        model.compressor.compress_with do |command, ext|
          pipeline << command
          dump_ext << ext
        end if model.compressor

        pipeline << "#{ utility(:cat) } > " +
            "'#{ File.join(dump_path, dump_filename) }.#{ dump_ext }'"

        pipeline.run

        unless pipeline.success?
          raise Error, "Dump Failed!\n" + pipeline.error_messages
        end
      end

      def save!
        resp = run("#{ redis_cli_cmd } SAVE")
        unless resp =~ /OK$/
          raise Error, <<-EOS
            Failed to invoke the `SAVE` command
            Response was: #{ resp }
          EOS
        end

      rescue Error
        if resp =~ /save already in progress/
          unless (attempts ||= '0').next! == '5'
            sleep 5
            retry
          end
        end
        raise
      end

      def copy!
        unless File.exist?(rdb_path)
          raise Error, <<-EOS
            Redis database dump not found
            `rdb_path` was '#{ rdb_path }'
          EOS
        end

        dst_path = File.join(dump_path, dump_filename + '.rdb')
        if model.compressor
          model.compressor.compress_with do |command, ext|
            run("#{ command } -c '#{ rdb_path }' > '#{ dst_path + ext }'")
          end
        else
          FileUtils.cp(rdb_path, dst_path)
        end
      end

      def redis_cli_cmd
        "#{ utility('redis-cli') } #{ password_option } " +
        "#{ connectivity_options } #{ user_options }"
      end

      def password_option
        "-a '#{ password }'" if password
      end

      def connectivity_options
        return "-s '#{ socket }'" if socket

        opts = []
        opts << "-h '#{ host }'" if host
        opts << "-p '#{ port }'" if port
        opts.join(' ')
      end

      def user_options
        Array(additional_options).join(' ')
      end

    end
  end
end
