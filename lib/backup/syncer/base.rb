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

      def initialize
        load_defaults!

        @path   ||= '~/backups'
        @mirror ||= false
        @directories = Array.new
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

      private

      def syncer_name
        self.class.to_s.sub('Backup::', '')
      end

    end
  end
end
