# encoding: utf-8

module Backup
  module Syncer
    module RSync
      class Base < Syncer::Base

        ##
        # Additional String or Array of options for the rsync cli
        attr_accessor :additional_rsync_options

        def initialize(syncer_id = nil, &block)
          super
          instance_eval(&block) if block_given?

          @path ||= '~/backups'
        end

        private

        ##
        # Common base command for Local/Push/Pull
        def rsync_command
          utility(:rsync) << ' --archive' << mirror_option << exclude_option <<
              " #{ Array(additional_rsync_options).join(' ') }".rstrip
        end

        def mirror_option
          mirror ? ' --delete' : ''
        end

        def exclude_option
          excludes.map {|pattern| " --exclude='#{ pattern }'" }.join
        end

        ##
        # Each path is expanded, since these refer to local paths and are
        # being shell-quoted. This will also remove any trailing `/` from
        # each path, as we don't want rsync's "trailing / on source directories"
        # behavior. This method is used by RSync::Local and RSync::Push.
        def paths_to_push
          directories.map {|dir| "'#{ File.expand_path(dir) }'" }.join(' ')
        end

      end
    end
  end
end
