# encoding: utf-8

module Backup
  module Syncer
    module RSync
      class Usb < Base
        attr_accessor :usb_mount

        def initialize(syncer_id = nil)
          super

          @path ||= '~/backups'
          @usb_mount ||= "~/usb"
        end
      
        def perform!
          log!(:started)

         if mount_usb
            create_dest_path!
            run("#{ rsync_command } #{ paths_to_push } '#{ dest_path }'")
            umount_usb
          else
            Logger.error Error.new(<<-EOS)
            Storage::Usb::Error: Usb File Copy Error!
              USB not mounted at #{@usb_mount}
            EOS
          end

          log!(:finished)
        end

        private

        # Expand path, since this is local and shell-quoted.
        def dest_path
          @dest_path ||= File.expand_path(path)
        end

        def create_dest_path!
          FileUtils.mkdir_p dest_path
        end

        # Mount the usb and return status
        def mount_usb
          `mount #{@usb_mount} 2>/dev/null`
          mounted?
        end

        # Unmount the usb
        def umount_usb
          `umount #{@usb_mount} 2>/dev/null`
        end

        # Test if the USB is mounted or not
        def mounted?
          # See if the remote path is included in the mounts
          mount_points.include?(@usb_mount)
        end

        # Get mount points from the system
        def mount_points
          `mount`.split("\n").grep(/dev/).map { |x| x.split(" ")[2]  }
        end
      end
    end
  end
end
