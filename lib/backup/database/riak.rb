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
        "riak-admin backup #{node} #{cookie} #{File.join(dump_path, name)} node"
      end

      ##
      # Performs the riak-admin command and outputs the
      # data to the specified path based on the 'trigger'
      def perform!
        super
        run("#{riakadmin}")
      end

    end
  end
end
