# encoding: utf-8

module Backup
  module Storage
    class Usb < Base
      class Error < Backup::Error; end

      attr_accessor :usb_mount
      
      def initialize(model, storage_id = nil)
        super

        @path ||= '~/backups'
        @usb_mount ||= "/mnt"
      end

      private

      def transfer!

        if mount_usb
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
