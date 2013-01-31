# encoding: utf-8

module Backup
  module Storage
    class Base
      include Backup::Configuration::Helpers

      ##
      # Sets the limit to how many backups to keep in the remote location.
      # If exceeded, the oldest will be removed to make room for the newest
      attr_accessor :keep

      ##
      # (Optional)
      # User-defined string used to uniquely identify multiple storages of the
      # same type. This will be appended to the YAML storage file used for
      # cycling backups.
      attr_accessor :storage_id

      ##
      # Creates a new instance of the storage object
      # * Called with super(model, storage_id) from each subclass
      def initialize(model, storage_id = nil)
        load_defaults!
        @model = model
        @storage_id = storage_id
      end

      ##
      # Performs the backup transfer
      def perform!
        @package = @model.package
        transfer!
        cycle!
      end

      private

      ##
      # Provider defaults to false. Overridden when using a service-based
      # storage such as Amazon S3, Rackspace Cloud Files or Dropbox
      def provider
        false
      end

      ##
      # Each subclass must define a +path+ where remote files will be stored
      def path; end

      ##
      # Return the storage name, with optional storage_id
      def storage_name
        self.class.to_s.sub('Backup::', '') +
            (storage_id ? " (#{storage_id})" : '')
      end

      ##
      # Returns the local path
      # This is where any Package to be transferred is located.
      def local_path
        Config.tmp_path
      end

      ##
      # Returns the remote path for the given Package
      # This is where the Package will be stored, or was previously stored.
      def remote_path_for(package)
        File.join(path, package.trigger, package.time)
      end

      ##
      # Yields two arguments to the given block: "local_file, remote_file"
      # The local_file is the full file name:
      # e.g. "2011.08.30.11.00.02.backup.tar.enc"
      # The remote_file is the full file name, minus the timestamp:
      # e.g. "backup.tar.enc"
      def files_to_transfer_for(package)
        package.filenames.each do |filename|
          yield filename, filename[20..-1]
        end
      end
      alias :transferred_files_for :files_to_transfer_for

      ##
      # Adds the current package being stored to the YAML cycle data file
      # and will remove any old Package file(s) when the storage limit
      # set by #keep is exceeded. Any errors raised while attempting to
      # remove older packages will be rescued and a warning will be logged
      # containing the original error message.
      def cycle!
        return unless keep.to_i > 0
        Logger.info "#{ storage_name }: Cycling Started..."
        Cycler.cycle!(self, @package)
        Logger.info "#{ storage_name }: Cycling Complete!"
      end

    end
  end
end
