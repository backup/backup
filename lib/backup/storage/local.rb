# encoding: utf-8

module Backup
  module Storage
    class Local < Base
      class Error < Backup::Error; end

      def initialize(model, storage_id = nil)
        super

        @path ||= '~/backups'
      end

      private

      def transfer!
        FileUtils.mkdir_p(remote_path)

        transfer_method = package_movable? ? :mv : :cp
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = File.join(remote_path, filename)
          Logger.info "Storing '#{ dest }'..."

          FileUtils.send(transfer_method, src, dest)
        end
      end

      # Called by the Cycler.
      # Any error raised will be logged as a warning.
      def remove!(package)
        Logger.info "Removing backup package dated #{ package.time }..."

        FileUtils.rm_r(remote_path_for(package))
      end

      # expanded since this is a local path
      def remote_path(pkg = package)
        File.expand_path(super)
      end
      alias :remote_path_for :remote_path

      ##
      # If this Local Storage is not the last Storage for the Model,
      # force the transfer to use a *copy* operation and issue a warning.
      def package_movable?
        if self == model.storages.last
          true
        else
          Logger.warn Error.new(<<-EOS)
            Local File Copy Warning!
            The final backup file(s) for '#{ model.label }' (#{ model.trigger })
            will be *copied* to '#{ remote_path }'
            To avoid this, when using more than one Storage, the 'Local' Storage
            should be added *last* so the files may be *moved* to their destination.
          EOS
          false
        end
      end

    end
  end
end
