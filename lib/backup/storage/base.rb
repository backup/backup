# encoding: utf-8

module Backup
  module Storage
    class Base
      include Backup::Configuration::Helpers

      ##
      # The time when the backup initiated (in format: 2011.02.20.03.29.59)
      attr_accessor :time

      ##
      # Sets the limit to how many backups to keep in the remote location.
      # If the limit exceeds it will remove the oldest backup to make room for the newest
      attr_accessor :keep

      ##
      # Returns the local path
      def local_path
        TMP_PATH
      end

      ##
      # See if there are multiple files that this backup model resulted in.
      def multiple_files?
        Backup::Model.current.file.is_a?(Array)
      end

      ##
      # Returns a list of local filenames
      def local_files
        @local_files ||= Backup::Model.file
        # Make sure that @local_files is an Array, regardless of being a single name or multiple names.
        @local_files = [@local_files].flatten
        # Just pull out the names
        @local_files.map! { |file_path| File.basename(file_path) }
      end

      ##
      # Returns the name(s) of the file(s) that('re) to be stored on the remote location
      def remote_files
        @remote_files ||= local_files
      end

      ##
      # Re-populates the list of remote files to sync to
      def create_remote_file_list
        @remote_files = local_files
      end

      ##
      # Provider defaults to false and will be overridden when using
      # a service-based storage such as Amazon S3, Rackspace Cloud Files or Dropbox
      def provider
        false
      end

      ##
      # Checks the persisted storage data by type (S3, CloudFiles, SCP, etc)
      # to see if the amount of stored backups is greater than the amount of
      # backups allowed. If this is the case it'll invoke the #remove! method
      # on each of the oldest backups that exceed the storage limit (specified by @keep).
      # After that it'll re-assign the objects variable with an array of objects that still remain
      # after the removal of the older objects and files (that exceeded the @keep range). And finally
      # these remaining objects will be converted to YAML format and are written back to the YAML file
      def cycle!
        type           = self.class.name.split("::").last
        storage_object = Backup::Storage::Object.new(type)
        objects        = [self] + storage_object.load
        if keep.is_a?(Integer) and keep > 0 and objects.count > keep
          objects_to_remove = objects[keep..-1]
          objects_to_remove.each do |object|
            Logger.message "#{ self.class } started removing (cycling) files from #{ object.class.name.split("::").last }"
            object.send(:remove!)
          end
          objects = objects - objects_to_remove
        end
        storage_object.write(objects)
      end

    end
  end
end
