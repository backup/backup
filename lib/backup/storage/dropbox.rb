# encoding: utf-8
require 'dropbox_sdk'

module Backup
  module Storage
    class Dropbox < Base
      include Storage::Cycler
      class Error < Backup::Error; end

      ##
      # Dropbox API credentials
      attr_accessor :api_key, :api_secret

      ##
      # Path to store cached authorized session.
      #
      # Relative paths will be expanded using Config.root_path,
      # which by default is ~/Backup unless --root-path was used
      # on the command line or set in config.rb.
      #
      # By default, +cache_path+ is '.cache', which would be
      # '~/Backup/.cache/' if using the default root_path.
      attr_accessor :cache_path

      ##
      # Dropbox Access Type
      # Valid values are:
      #   :app_folder (default)
      #   :dropbox (full access)
      attr_accessor :access_type

      ##
      # Chunk size, specified in MiB, for the ChunkedUploader.
      attr_accessor :chunk_size

      ##
      # Number of times to retry failed operations.
      #
      # Default: 10
      attr_accessor :max_retries

      ##
      # Time in seconds to pause before each retry.
      #
      # Default: 30
      attr_accessor :retry_waitsec

      ##
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil)
        super

        @path           ||= 'backups'
        @cache_path     ||= '.cache'
        @access_type    ||= :app_folder
        @chunk_size     ||= 4 # MiB
        @max_retries    ||= 10
        @retry_waitsec  ||= 30
        path.sub!(/^\//, '')
      end

      private

      def cloud_io
        @cloud_io ||= CloudIO::Dropbox.new(
          :api_key       => api_key,
          :api_secret    => api_secret,
          :cache_path    => cache_path,
          :access_type   => access_type,
          :max_retries   => max_retries,
          :retry_waitsec => retry_waitsec,
          :chunk_size    => chunk_size
        )
      end

      ##
      # Transfer each of the package files to Dropbox in chunks of +chunk_size+.
      # Each chunk will be retried +chunk_retries+ times, pausing +retry_waitsec+
      # between retries, if errors occur.
      def transfer!
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = File.join(remote_path, filename)
          Logger.info "Storing '#{ dest }'..."
          cloud_io.upload(src, dest)
        end
      end

      # Called by the Cycler.
      # Any error raised will be logged as a warning.
      def remove!(package)
        Logger.info "Removing backup package dated #{ package.time }..."

        remote_path = remote_path_for(package)
        objects = cloud_io.objects(remote_path)

        raise Error, "Package at '#{ remote_path }' not found" if objects.empty?
        cloud_io.delete(objects)
        cloud_io.delete_folder(remote_path)
      end

    end
  end
end
