# encoding: utf-8

module Backup
  module Database
    class MongoDB < Base

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

      ##
      # Creates a new instance of the MongoDB database object
      def initialize(&block)
        load_defaults!

        @only_collections   ||= Array.new
        @additional_options ||= Array.new
        @ipv6               ||= false
        @lock               ||= false

        instance_eval(&block)
      end

      ##
      # Builds the MongoDB credentials syntax to authenticate the user
      # to perform the database dumping process
      def credential_options
        %w[username password].map do |option|
          next if send(option).nil? or send(option).empty?
          "--#{option}='#{send(option)}'"
        end.compact.join("\s")
      end

      ##
      # Builds the MongoDB connectivity options syntax to connect the user
      # to perform the database dumping process
      def connectivity_options
        %w[host port].map do |option|
          next if send(option).nil? or (send(option).respond_to?(:empty?) and send(option).empty?)
          "--#{option}='#{send(option)}'"
        end.compact.join("\s")
      end

      ##
      # Builds a MongoDB compatible string for the
      # additional options specified by the user
      def additional_options
        @additional_options.join("\s")
      end

      ##
      # Returns an array of collections to dump
      def collections_to_dump
        @only_collections
      end

      ##
      # Returns the MongoDB database selector syntax
      def database
        "--db='#{ name }'"
      end

      ##
      # Returns the mongodump syntax for enabling ipv6
      def ipv6
        @ipv6.eql?(true) ? '--ipv6' : ''
      end

      ##
      # Returns the MongoDB syntax for determining where to output all the database dumps,
      # e.g. ~/Backup/.tmp/MongoDB/<databases here>/<database collections>
      def dump_directory
        "--out='#{ dump_path }'"
      end

      ##
      # Builds the full mongodump string based on all attributes
      def mongodump
        "#{ utility(:mongodump) } #{ database } #{ credential_options } " +
        "#{ connectivity_options } #{ ipv6 } #{ additional_options } #{ dump_directory }"
      end

      ##
      # Performs the mongodump command and outputs the data to the
      # specified path based on the 'trigger'. If the user hasn't specified any
      # specific collections to dump, it'll dump everything. If the user has specified
      # collections to dump, it'll loop through the array of collections and invoke the
      # 'mongodump' command once per collection
      def perform!
        super

        lock_database if @lock.eql?(true)
        if collections_to_dump.is_a?(Array) and not collections_to_dump.empty?
          specific_collection_dump!
        else
          dump!
        end
        unlock_database if @lock.eql?(true)
      rescue => exception
        unlock_database if @lock.eql?(true)
        raise exception
      end

      ##
      # Builds and runs the mongodump command
      def dump!
        run(mongodump)
      end

      ##
      # For each collection in the @only_collections array, it'll
      # build the whole 'mongodump' command, append the '--collection' option,
      # and run the command built command
      def specific_collection_dump!
        collections_to_dump.each do |collection|
          run("#{mongodump} --collection='#{collection}'")
        end
      end

      ##
      # Builds the full mongo string based on all attributes
      def mongo_shell
        [utility(:mongo), database, credential_options, connectivity_options, ipv6].join(' ')
      end

      ##
      # Locks and FSyncs the database to bring it up to sync
      # and ensure no 'write operations' are performed during the
      # dump process
      def lock_database
        lock_command = <<-EOS
          echo 'use admin
          db.runCommand({"fsync" : 1, "lock" : 1})' | #{mongo_shell}
        EOS

        run(lock_command)
      end

      ##
      # Unlocks the (locked) database
      def unlock_database
        unlock_command = <<-EOS
          echo 'use admin
          db.$cmd.sys.unlock.findOne()' | #{mongo_shell}
        EOS

        run(unlock_command)
      end

    end
  end
end
