# encoding: utf-8

module Backup
  module Database
    class Redis < Base
      class Error < Backup::Error; end

      ##
      # Name of the redis dump file.
      #
      # This is set in `redis.conf` as `dbfilename`.
      # This must be set to the name of that file without the `.rdb` extension.
      # Default: 'dump'
      attr_accessor :name

      ##
      # Path to the redis dump file.
      #
      # This is set in `redis.conf` as `dir`.
      attr_accessor :path

      ##
      # Password for the redis-cli utility to perform the `SAVE` command
      # if +invoke_save+ is set `true`.
      attr_accessor :password

      ##
      # Connectivity options for the +invoke_save+ option.
      attr_accessor :host, :port, :socket

      ##
      # Determines whether Backup should invoke the `SAVE` command through
      # the `redis-cli` utility to persist the most recent data before
      # copying the dump file specified by +path+ and +name+.
      attr_accessor :invoke_save

      ##
      # Additional "redis-cli" options
      attr_accessor :additional_options

      def initialize(model, database_id = nil, &block)
        super
        instance_eval(&block) if block_given?

        @name ||= 'dump'
      end

      ##
      # Copies and optionally compresses the Redis dump file to the
      # +dump_path+ using the +dump_filename+.
      #
      #   <trigger>/databases/Redis[-<database_id>].rdb[.gz]
      #
      # If +invoke_save+ is true, `redis-cli SAVE` will be invoked.
      def perform!
        super

        invoke_save! if invoke_save
        copy!

        log!(:finished)
      end

      private

      def invoke_save!
        resp = run(redis_save_cmd)
        unless resp =~ /OK$/
          raise Error, <<-EOS
            Could not invoke the Redis SAVE command.
            Command was: #{ redis_save_cmd }
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
        src_path = File.join(path, name + '.rdb')
        unless File.exist?(src_path)
          raise Error, <<-EOS
            Redis database dump not found
            File path was #{ src_path }
          EOS
        end

        dst_path = File.join(dump_path, dump_filename + '.rdb')
        if model.compressor
          model.compressor.compress_with do |command, ext|
            run("#{ command } -c '#{ src_path }' > '#{ dst_path + ext }'")
          end
        else
          FileUtils.cp(src_path, dst_path)
        end
      end

      def redis_save_cmd
        "#{ utility('redis-cli') } #{ password_option } " +
        "#{ connectivity_options } #{ user_options } SAVE"
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

      attr_deprecate :utility_path, :version => '3.0.21',
          :message => 'Use Backup::Utilities.configure instead.',
          :action => lambda {|klass, val|
            Utilities.configure { redis_cli val }
          }

      attr_deprecate :redis_cli_utility, :version => '3.3.0',
          :message => 'Use Backup::Utilities.configure instead.',
          :action => lambda {|klass, val|
            Utilities.configure { redis_cli val }
          }

    end
  end
end
