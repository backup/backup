# encoding: utf-8

module Backup
  module Configuration
    module Database
      class MongoDB < Base
        class << self

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
          # 'lock' dump meaning wrapping mongodump with fsync & lock
          attr_accessor :lock

        end
      end
    end
  end
end
