# encoding: utf-8

module Backup
  module Syncer
    class Base
      include Backup::Utilities::Helpers
      include Backup::Configuration::Helpers

      ##
      # Path to store the synced files/directories to
      attr_accessor :path

      ##
      # Flag for mirroring the files/directories
      attr_accessor :mirror

      ##
      # Optional user-defined identifier to differentiate multiple syncers
      # defined within a single backup model. Currently this is only used
      # in the log messages.
      attr_reader :syncer_id

      attr_reader :excludes

      def initialize(syncer_id = nil)
        @syncer_id = syncer_id

        load_defaults!

        @mirror ||= false
        @directories = []
        @excludes = []
      end

      ##
      # Syntactical suger for the DSL for adding directories
      def directories(&block)
        return @directories unless block_given?
        instance_eval(&block)
      end

      def add(path)
        directories << path
      end

      # For Cloud Syncers, +pattern+ can be a string (with shell-style
      # wildcards) or a regex.
      # For RSync, each +pattern+ will be passed to rsync's --exclude option.
      def exclude(pattern)
        excludes << pattern
      end

      private

      def syncer_name
        @syncer_name ||= self.class.to_s.sub('Backup::', '') +
            (syncer_id ? " (#{ syncer_id })" : '')
      end

      def log!(action)
        msg = case action
              when :started then 'Started...'
              when :finished then 'Finished!'
              end
        Logger.info "#{ syncer_name } #{ msg }"
      end

    end
  end
end
