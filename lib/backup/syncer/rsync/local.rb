# encoding: utf-8

##
# Require the tempfile Ruby library when Backup::Syncer::RSync is loaded
require 'tempfile'

module Backup
  module Syncer
    module RSync
      class Local < Syncer::Base

        ##
        # Directories to sync
        attr_writer :directories

        ##
        # Path to store the synced files/directories to
        attr_accessor :path

        ##
        # Flag for mirroring the files/directories
        attr_writer :mirror

        ##
        # Additional options for the rsync cli
        attr_accessor :additional_options

        ##
        # Instantiates a new RSync Syncer object and sets the default configuration
        # specified in the Backup::Configuration::Syncer::RSync. Then it sets the object
        # defaults if particular properties weren't set. Finally it'll evaluate the users
        # configuration file and overwrite anything that's been defined
        def initialize(&block)
          load_defaults!

          @directories          = Array.new
          @additional_options ||= Array.new
          @path               ||= 'backups'
          @mirror             ||= false

          instance_eval(&block) if block_given?

          @path = path.sub(/^\~\//, '')
        end

        ##
        # Performs the RSync operation
        # debug options: -vhP
        def perform!
          Logger.message("#{ self.class } started syncing #{ directories }.")
          Logger.silent(
            run("#{ utility(:rsync) } #{ options } #{ directories } '#{ path }'")
          )
        end

        ##
        # Returns all the specified Rsync options, concatenated, ready for the CLI
        def options
          ([archive, mirror] + additional_options).compact.join("\s")
        end

        ##
        # Returns Rsync syntax for enabling mirroring
        def mirror
          '--delete' if @mirror
        end

        ##
        # Returns Rsync syntax for invoking "archive" mode
        def archive
          '--archive'
        end

        ##
        # If no block has been provided, it'll return the array of @directories.
        # If a block has been provided, it'll evaluate it and add the defined paths to the @directories
        def directories(&block)
          unless block_given?
            return @directories.map do |directory|
              "'#{directory}'"
            end.join("\s")
          end
          instance_eval(&block)
        end

        ##
        # Adds a path to the @directories array
        def add(path)
          @directories << path
        end
      end
    end
  end
end
