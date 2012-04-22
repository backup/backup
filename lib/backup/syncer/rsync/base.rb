# encoding: utf-8

module Backup
  module Syncer
    module RSync
      class Base < Syncer::Base
        ##
        # Additional options for the rsync cli
        attr_accessor :additional_options

        ##
        # Instantiates a new RSync Syncer object
        # and sets the default configuration
        def initialize
          super

          @additional_options ||= Array.new
        end

        private

        ##
        # Returns the @directories as a space-delimited string of
        # single-quoted values for use in the `rsync` command line.
        # Each path is expanded, since these refer to local paths
        # for both RSync::Local and RSync::Push.
        # RSync::Pull does not use this method.
        def directories_option
          @directories.map do |directory|
            "'#{ File.expand_path(directory) }'"
          end.join(' ')
        end

        ##
        # Returns Rsync syntax for enabling mirroring
        def mirror_option
          '--delete' if @mirror
        end

        ##
        # Returns Rsync syntax for invoking "archive" mode
        def archive_option
          '--archive'
        end

      end
    end
  end
end
