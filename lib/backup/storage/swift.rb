# encoding: utf-8
require 'backup/cloud_io/swift'

module Backup
  module Storage
    class Swift < Base
      include Storage::Cycler
      class Error < Backup::Error; end

      ##
      # Swift credentials
      attr_accessor :username, :password

      ##
      # Keystone tenant name if using v2 auth
      attr_accessor :tenant_name

      ##
      # Swift container name
      attr_accessor :container

      ##
      # Swift region. It might be required for certain providers
      attr_accessor :region

      ##
      # OpenStack keystone url
      attr_accessor :auth_url

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
      # The size of the batch operations (delete/list/etc.) in your
      # OpenStack deployment
      #
      # Default: 1000
      attr_accessor :batch_size

      ##
      # Additional options to pass along to fog.
      # e.g. Fog::Storage.new({ :provider => 'Swift' }.merge(fog_options))
      attr_accessor :fog_options

      def initialize(mode, storage_id = nil)
        super

        @max_retries    ||= 10
        @retry_waitsec  ||= 30
        @path           ||= 'backups'
        @batch_size     ||= 1000
        @fog_options    ||= {}

        @path = @path.sub(/^\//, '')

        check_configuration
      end

      private

      def cloud_io
        @cloud_io ||= CloudIO::Swift.new(
          username:             username,
          password:             password,
          tenant_name:          tenant_name,
          region:               region,
          container:            container,
          auth_url:             auth_url,
          max_retries:          max_retries,
          retry_waitsec:        retry_waitsec,
          batch_size:           batch_size,
          fog_options:          fog_options,
        )
      end

      def transfer!
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = File.join(remote_path, filename)
          Logger.info "Storing '#{ container }/#{ dest }'..."
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
      end

      def check_configuration
        if auth_url.nil?
          raise Error, <<-EOS
            Configuration Error
            Swift auth_url is required
          EOS
        end

        required = [:username, :password, :container, :auth_url]
        required << :tenant_name if auth_url =~ /v2/

        raise Error, <<-EOS if required.map {|name| send(name) }.any?(&:nil?)
          Configuration Error
          #{ required.map {|name| "##{ name }"}.join(', ') } are all required
        EOS
      end

    end
  end
end
