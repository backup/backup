# encoding: utf-8

module Backup
  module Syncer
    class Base
      include Backup::CLI::Helpers
      include Backup::Configuration::Helpers

      ##
      # Directories to sync
      attr_accessor :directories

      ##
      # Path to store the synced files/directories to
      attr_accessor :path

      ##
      # Flag for mirroring the files/directories
      attr_accessor :mirror

      ##
      # Syntactical suger for the DSL for adding directories
      def directories(&block)
        return @directories unless block_given?
        instance_eval(&block)
      end

      ##
      # Adds a path to the @directories array
      def add(path)
        @directories << path
      end

      private

      def syncer_name
        self.class.to_s.sub('Backup::', '')
      end

    end
  end
end
