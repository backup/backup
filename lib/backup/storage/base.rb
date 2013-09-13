# encoding: utf-8

module Backup
  module Storage
    class Base
      include Backup::Configuration::Helpers

      ##
      # Base path on the remote where backup package files will be stored.
      attr_accessor :path

      ##
      # Sets the limit to how many backups to keep in the remote location.
      # If exceeded, the oldest will be removed to make room for the newest
      attr_accessor :keep

      attr_reader :model, :package, :storage_id

      ##
      # +storage_id+ is a user-defined string used to uniquely identify
      # multiple storages of the same type. If multiple storages of the same
      # type are added to a single backup model, this identifier must be set.
      # This will be appended to the YAML storage file used for cycling backups.
      def initialize(model, storage_id = nil, &block)
        @model = model
        @package = model.package
        @storage_id = storage_id.to_s.gsub(/\W/, '_') if storage_id

        load_defaults!
        instance_eval(&block) if block_given?
      end

      def perform!
        Logger.info "#{ storage_name } Started..."
        transfer!
        cycle!
        Logger.info "#{ storage_name } Finished!"
      end

      private

      ##
      # Return the remote path for the current or given package.
      def remote_path(pkg = package)
        File.join(path, pkg.trigger, pkg.time)
      end
      alias :remote_path_for :remote_path

      ##
      # Adds the current package being stored to the YAML cycle data file
      # and will remove any old Package file(s) when the storage limit
      # set by #keep is exceeded. Any errors raised while attempting to
      # remove older packages will be rescued and a warning will be logged
      # containing the original error message.
      def cycle!
        return unless keep.to_i > 0
        Logger.info "Cycling Started..."
        Cycler.cycle!(self)
      end

      def storage_name
        @storage_name ||= self.class.to_s.sub('Backup::', '') +
            (storage_id ? " (#{ storage_id })" : '')
      end

    end
  end
end
