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
      # Contains an array of chunk suffixes (if any)
      # If none are set, this will be nil, in which case Backup assumes
      # no splitting
      attr_accessor :chunk_suffixes

      ##
      # Super method for the child classes' perform! method. "super" should
      # always be invoked from the child classes' perform! method to ensure that the
      # @chunk_suffixes array gets set to the storage object, which will be used to transfer all the
      # chunks to the remote location, rather than the single backup file. Also, this will be persisted
      # and loaded back in during the cycling process, so it gets properly deleted from the remote location.
      def perform!
        @chunk_suffixes ||= Backup::Model.chunk_suffixes
      end

      ##
      # Returns the full filename of the processed backup file
      def filename
        @filename ||= File.basename(Backup::Model.file)
      end

      ##
      # Returns the local path
      def local_path
        TMP_PATH
      end

      ##
      # Returns an array of backup chunks
      def chunks
        chunk_suffixes.map do |chunk_suffix|
          "#{ filename }-#{ chunk_suffix }"
        end.sort
      end

      ##
      # Returns a block with two arguments: "local_file, remote_file"
      # The local_file is the full file name: "2011.08.30.11.00.02.backup.tar.gz.enc"
      # The remote_file is the full file name, minus the timestamp: "backup.tar.gz.enc"
      def files_to_transfer
        if chunks?
          chunks.each do |chunk|
            yield chunk, chunk[20..-1]
          end
        else
          yield filename, filename[20..-1]
        end
      end

      alias :transferred_files :files_to_transfer

      ##
      # Returns true if we're working with chunks
      # that were splitted by Backup
      def chunks?
        chunk_suffixes.is_a?(Array) and chunk_suffixes.count > 0
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
            Logger.message "#{ self.class } started removing (cycling) \"#{ object.filename }\"."
            object.send(:remove!)
          end
          objects = objects - objects_to_remove
        end
        storage_object.write(objects)
      end

    end
  end
end
