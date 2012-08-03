# encoding: utf-8

module Backup
  module Database
    class Riak < Base

      ##
      # Name is the name of the backup
      attr_accessor :name

      ##
      # Node is the node from which to perform the backup.
      attr_accessor :node

      ##
      # Cookie is the Erlang cookie/shared secret used to connect to the node.
      attr_accessor :cookie

      ##
      # Path to riak-admin utility (optional)
      attr_accessor :riak_admin_utility

      attr_deprecate :utility_path, :version => '3.0.21',
          :message => 'Use Riak#riak_admin_utility instead.',
          :action => lambda {|klass, val| klass.riak_admin_utility = val }

      ##
      # Creates a new instance of the Riak adapter object
      def initialize(model, &block)
        super(model)

        instance_eval(&block) if block_given?

        @riak_admin_utility ||= utility('riak-admin')
      end

      ##
      # Performs the riak-admin command and outputs the
      # data to the specified path based on the 'trigger'
      def perform!
        super
        # have to make riak the owner since the riak-admin tool runs
        # as the riak user in a default setup.
        FileUtils.chown_R('riak', 'riak', @dump_path)

        backup_file = File.join(@dump_path, name)
        run("#{ riakadmin } #{ backup_file } node")

        if @model.compressor
          @model.compressor.compress_with do |command, ext|
            run("#{ command } -c #{ backup_file } > #{ backup_file + ext }")
            FileUtils.rm_f(backup_file)
          end
        end
      end

      private

      ##
      # Builds the full riak-admin string based on all attributes
      def riakadmin
        "#{ riak_admin_utility } backup #{ node } #{ cookie }"
      end

    end
  end
end
