# encoding: utf-8

module Backup
  module Storage
    class Base

      ##
      # The time when the backup initiated (in format: 2011.02.20.03.29.59)
      attr_accessor :time

      ##
      # Returns true or false based on whether the file has been transferred or not
      attr_accessor :transferred
      alias :transferred? :transferred

      ##
      # Returns the local path
      def local_path
        TMP_PATH
      end

      ##
      # This is the remote path to where the backup files will be stored
      def remote_path
        File.join('backup', TRIGGER, '/')
      end

      ##
      # Returns the local archive filename
      def local_file
        @local_file ||= File.basename(Backup::Model.file)
      end

      ##
      # Returns the name of the file that's stored on the remote location
      def remote_file
        @remote_file ||= local_file
      end

      ##
      # Provider defaults to false and will be overridden when using
      # a service-based storage such as Amazon S3, Rackspace Cloud Files or Dropbox
      def provider
        false
      end

    end
  end
end
