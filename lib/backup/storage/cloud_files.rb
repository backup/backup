# encoding: utf-8
require 'backup/cloud_io/cloud_files'

module Backup
  module Storage
    class CloudFiles < Base
      class Error < Backup::Error; end

      ##
      # Rackspace CloudFiles Credentials
      attr_accessor :username, :api_key

      ##
      # Rackspace Auth URL (optional)
      attr_accessor :auth_url

      ##
      # Rackspace Service Net
      # (LAN-based transfers to avoid charges and improve performance)
      attr_accessor :servicenet

      ##
      # Rackspace Region (optional)
      attr_accessor :region

      ##
      # Rackspace Container Name
      attr_accessor :container

      ##
      # Rackspace Container Name for SLO Segments
      # Required if #segment_size is set. Must be different from #container.
      attr_accessor :segments_container

      ##
      # SLO Segment size, specified in MiB.
      #
      # Each package file larger than +segment_size+
      # will be uploaded as a Static Large Objects (SLO).
      #
      # Defaults to 0 for backward compatibility (pre v.3.7.0),
      # since #segments_container would be required.
      #
      # Minimum: 1 (0 disables SLO support)
      # Maximum: 5120 (5 GiB)
      attr_accessor :segment_size

      ##
      # If set, all backup package files (including SLO segments) will be
      # scheduled for automatic removal by the server.
      #
      # The `keep` option should not be used if this is set,
      # unless you're transitioning from the `keep` option.
      attr_accessor :days_to_keep

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
      # e.g. Fog::Storage.new({ :provider => 'Rackspace' }.merge(fog_options))
      attr_accessor :fog_options

      def initialize(model, storage_id = nil)
        super

        @servicenet         ||= false
        @segment_size       ||= 0
        @max_retries        ||= 10
        @retry_waitsec      ||= 30

        @path ||= 'backups'
        path.sub!(/^\//, '')

        check_configuration
      end

      private

      def cloud_io
        @cloud_io ||= CloudIO::CloudFiles.new(
          :username           => username,
          :api_key            => api_key,
          :auth_url           => auth_url,
          :region             => region,
          :servicenet         => servicenet,
          :container          => container,
          :segments_container => segments_container,
          :segment_size       => segment_size,
          :days_to_keep       => days_to_keep,
          :max_retries        => max_retries,
          :retry_waitsec      => retry_waitsec,
          :fog_options        => fog_options
        )
      end

      def transfer!
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = File.join(remote_path, filename)
          Logger.info "Storing '#{ container }/#{ dest }'..."
          cloud_io.upload(src, dest)
        end

        package.no_cycle = true if days_to_keep
      end

      # Called by the Cycler.
      # Any error raised will be logged as a warning.
      def remove!(package)
        Logger.info "Removing backup package dated #{ package.time }..."

        remote_path = remote_path_for(package)
        objects = cloud_io.objects(remote_path)

        raise Error, "Package at '#{ remote_path }' not found" if objects.empty?

        slo_objects, objects = objects.partition(&:slo?)
        cloud_io.delete_slo(slo_objects)
        cloud_io.delete(objects)
      end

      def check_configuration
        required = %w{ username api_key container }
        raise Error, <<-EOS if required.map {|name| send(name) }.any?(&:nil?)
          Configuration Error
          #{ required.map {|name| "##{ name }"}.join(', ') } are all required
        EOS

        raise Error, <<-EOS if segment_size > 0 && segments_container.to_s.empty?
          Configuration Error
          #segments_container is required if #segment_size is > 0
        EOS

        raise Error, <<-EOS if container == segments_container
          Configuration Error
          #container and #segments_container must not be the same container.
        EOS

        raise Error, <<-EOS if segment_size > 5120
          Configuration Error
          #segment_size is too large (max 5120)
        EOS
      end

    end
  end
end
