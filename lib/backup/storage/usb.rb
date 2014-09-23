# encoding: utf-8

module Backup
  module Storage
    class Usb < Base
      class Error < Backup::Error; end

      ##
      #
      # USB storage
      #
      # Copy your backups over to a USB drive to take off-site.
      #
      # If you are using a FAT32 file system I recommend using the 'split_into_chunks_of 2000'
      #

      ##
      # Usb mount
      # This is where you want to mount your USB drive.
      # eg:
      #   store_with Usb do |usb|
      #     usb.path = "/home/myuser/usb/test"
      #     usb.usb_mount = "/home/myuser/usb"
      #   end
      #
      # Make sure you create the mount directory and it has the correct permissions.
      #
      # I also put this into my /etc/crontab
      # /dev/disk/by-label/BACKUP	/home/myuser/usb	  auto	rw,noauto,user,exec	0	0
      #
      attr_accessor :usb_mount, :remove_old
      
      def initialize(model, storage_id = nil)
        super

        @path ||= '~/usb/backups'
        @usb_mount ||= "~/usb"
        @remove_old ||= false
      end

      private

      def transfer!

        if mount_usb
          FileUtils.rm_r(@path) if File.exists?(@path) && @remove_old # Remove old directory
          
          FileUtils.mkdir_p(remote_path)

          package.filenames.each do |filename|
            src = File.join(Config.tmp_path, filename)
            dest = File.join(remote_path, filename)
            Logger.info "Storing '#{ dest }'..."

            FileUtils.send(:cp, src, dest)
          end

          umount_usb
        else
          Logger.error Error.new(<<-EOS)
            Storage::Usb::Error: Usb File Copy Error!
              USB not mounted at #{@usb_mount}
          EOS
        end
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

      # expanded since this is a local path
      def remote_path(pkg = package)
        File.expand_path(super)
      end
      alias :remote_path_for :remote_path
    end
  end
end
