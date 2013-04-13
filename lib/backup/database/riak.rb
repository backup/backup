# encoding: utf-8

module Backup
  module Database
    class Riak < Base

      ##
      # Node is the node from which to perform the backup.
      # Default: riak@127.0.0.1
      attr_accessor :node

      ##
      # Cookie is the Erlang cookie/shared secret used to connect to the node.
      # Default: riak
      attr_accessor :cookie

      ##
      # Username for the riak instance
      # Default: riak
      attr_accessor :user

      def initialize(model, database_id = nil, &block)
        super
        instance_eval(&block) if block_given?

        @node   ||= 'riak@127.0.0.1'
        @cookie ||= 'riak'
        @user   ||= 'riak'
      end

      ##
      # Performs the dump using `riak-admin backup`.
      #
      # This will be stored in the final backup package as
      # <trigger>/databases/<dump_filename>-<node>[.gz]
      def perform!
        super

        dump_file = File.join(dump_path, dump_filename)
        with_riak_owned_dump_path do
          run("#{ riakadmin } backup #{ node } #{ cookie } '#{ dump_file }' node")
        end

        model.compressor.compress_with do |command, ext|
          dump_file << "-#{ node }" # `riak-admin` appends `node` to the filename.
          run("#{ command } -c '#{ dump_file }' > '#{ dump_file + ext }'")
          FileUtils.rm_f(dump_file)
        end if model.compressor

        log!(:finished)
      end

      private

      ##
      # The `riak-admin backup` command is run as the riak +user+,
      # so +user+ must have write priviledges to the +dump_path+.
      #
      # Note that the riak +user+ must also have access to +dump_path+.
      # This means Backup's +tmp_path+ can not be under the home directory of
      # the user running Backup, since the absence of the execute bit on their
      # home directory would deny +user+ access.
      def with_riak_owned_dump_path
        run("#{ utility(:sudo) } -n #{ utility(:chown) } " +
            "#{ user } '#{ dump_path }'")
        yield
      ensure
        # reclaim ownership
        run("#{ utility(:sudo) } -n #{ utility(:chown) } -R " +
            "#{ Config.user } '#{ dump_path }'")
      end

      ##
      # `riak-admin` must be run as the riak +user+.
      # It will do this itself, but without `-n` and emits a message on STDERR.
      def riakadmin
        "#{ utility(:sudo) } -n -u #{ user } #{ utility('riak-admin') }"
      end

      attr_deprecate :utility_path, :version => '3.0.21',
          :message => 'Use Backup::Utilities.configure instead.',
          :action => lambda {|klass, val|
            Utilities.configure { riak_admin val }
          }

      attr_deprecate :riak_admin_utility, :version => '3.3.0',
          :message => 'Use Backup::Utilities.configure instead.',
          :action => lambda {|klass, val|
            Utilities.configure { riak_admin val }
          }

      attr_deprecate :name, :version => '3.3.0',
          :message => "If you wish to add an identifier to the dump filename,\n" +
          "use a +database_id+ when defining the database in your Model.\n" +
          "e.g. database Riak, :my_id do |db|"

      attr_deprecate :group, :version => '3.3.0'

    end
  end
end
