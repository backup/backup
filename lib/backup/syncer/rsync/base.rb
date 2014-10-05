# encoding: utf-8

module Backup
  module Syncer
    module RSync
      class Base < Syncer::Base
        class Error < Backup::Error; end


        ##
        # Additional String or Array of options for the rsync cli
        attr_accessor :additional_rsync_options

        # Boolean indicating if the specified path is expected to be a
        # mounted removable storage location.
        attr_accessor :removable_storage

        def initialize(syncer_id = nil, &block)
          super
          instance_eval(&block) if block_given?

          @path ||= '~/backups'
          @removable_storage ||= false
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

        ##
        # Get a list of all mount points
        def mount_points
          points = `mount`.split("\n").grep(/dev/).map { |x| x.split(" ")[2]  }
          points.reject{ |x| %w(/ /dev /home /var /tmp).include? x } # Exclude local mounts
        end

        ##
        # Check if the remote path is mounted.
        def mounted?
          return true unless removable_storage
          return true if mount_points.select { |mount_point| path.include?(mount_point)}.length > 0

          Logger.error Error.new(<<-EOS)
            Removable storage location '#{path}' does not exist!
            Make sure the removable storage is mounted and available.
          EOS
          false
        end

      end
    end
  end
end
