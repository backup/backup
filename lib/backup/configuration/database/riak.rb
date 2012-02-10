# encoding: utf-8

module Backup
  module Configuration
    module Database
      class Riak < Base
        class << self

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

        end
      end
    end
  end
end
