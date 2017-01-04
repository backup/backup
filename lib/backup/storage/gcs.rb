# encoding: utf-8
require "backup/cloud_io/gcs"

module Backup
  module Storage
    class GCS < Base
      include Storage::Cycler
      class Error < Backup::Error; end

      ##
      # Google XML API credentials
      attr_accessor :google_storage_secret_access_key
      attr_accessor :google_storage_access_key_id

      ##
      # Amazon GCS bucket name
      attr_accessor :bucket

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
      # Additional options to pass along to fog.
      # e.g. Fog::Storage.new({ :provider => 'AWS' }.merge(fog_options))
      attr_accessor :fog_options

      def initialize(model, storage_id = nil)
        super

        @max_retries    ||= 10
        @retry_waitsec  ||= 30
        @path           ||= "backups"
        @path = @path.sub(%r{^/}, "")

        check_configuration
      end

      private

      def cloud_io
        @cloud_io ||= CloudIO::GCS.new(
          google_storage_secret_access_key: google_storage_secret_access_key,
          google_storage_access_key_id: google_storage_access_key_id,
          bucket: bucket,
          max_retries: max_retries,
          retry_waitsec: retry_waitsec,
          fog_options: fog_options
        )
      end

      def transfer!
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = File.join(remote_path, filename)
          Logger.info "Storing '#{bucket}/#{dest}'..."
          cloud_io.upload(src, dest)
        end
      end

      # Called by the Cycler.
      # Any error raised will be logged as a warning.
      def remove!(package)
        Logger.info "Removing backup package dated #{package.time}..."

        remote_path = remote_path_for(package)
        objects = cloud_io.objects(remote_path)

        raise Error, "Package at '#{remote_path}' not found" if objects.empty?

        cloud_io.delete(objects)
      end

      def check_configuration
        required =
          %w(google_storage_secret_access_key google_storage_access_key_id bucket)

        raise Error, <<-EOS if required.map { |name| send(name) }.any?(&:nil?)
          Configuration Error
          #{required.map { |name| "##{name}" }.join(", ")} are all required
        EOS
      end
    end
  end
end
