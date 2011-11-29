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
      # Creates a new instance of the Riak adapter object
      def initialize(&block)
        load_defaults!

        instance_eval(&block)
      end

      ##
      # Builds the full riak-admin string based on all attributes
      def riakadmin
        "riak-admin backup #{node} #{cookie}"
      end

      ##
      # Performs the riak-admin command and outputs the
      # data to the specified path based on the 'trigger'
      def perform!
        super
        # have to make riak the owner since the riak-admin tool runs as the riak user in a default setup.
        run("chown -R riak.riak #{dump_path}")
        run("#{riakadmin} #{File.join(dump_path, name)} node")
      end

    end
  end
end
