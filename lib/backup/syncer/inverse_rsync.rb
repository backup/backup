# encoding: utf-8

##
# Require the tempfile Ruby library when Backup::Syncer::RSync is loaded
require 'tempfile'

module Backup
  module Syncer
    class InverseRSync < RSync
      ##
      # Directories to sync
      attr_accessor :remote_path

      ##
      # Path to store the synced files/directories to
      attr_accessor :local_path

      ##
      # Instantiates a new RSync Syncer object and sets the default configuration
      # specified in the Backup::Configuration::Syncer::RSync. Then it sets the object
      # defaults if particular properties weren't set. Finally it'll evaluate the users
      # configuration file and overwrite anything that's been defined
      def initialize(&block)
        load_defaults!

        @directories          = Array.new
        @additional_options ||= Array.new
        @local_path         ||= File.join('backups', TRIGGER)
        @port               ||= 22
        @mirror             ||= false
        @compress           ||= false

        instance_eval(&block) if block_given?
        write_password_file!
      end

      ##
      # Performs the RSync operation
      # debug options: -vhP
      # recursively (-r option)
      def perform!
        Logger.message("#{ self.class } started syncing #{ remote_path }.")
        Logger.silent(run("mkdir -p #{ local_path }"))
        Logger.silent(
          run("#{ utility(:rsync) } -vhPr #{ options } '#{ username }@#{ ip }:#{ remote_path }' '#{ local_path }'")
        )

        remove_password_file!
      end
    end
  end
end
