# encoding: utf-8
require 'fog'

module Backup
  module Storage
    class CloudFiles < Base

      ##
      # Rackspace Cloud Files Credentials
      attr_accessor :username, :api_key, :auth_url

      ##
      # Rackspace Service Net
      # (LAN-based transfers to avoid charges and improve performance)
      attr_accessor :servicenet

      ##
      # Rackspace Cloud Files container name
      attr_accessor :container

      def initialize(model, storage_id = nil, &block)
        super
        instance_eval(&block) if block_given?

        @servicenet ||= false
        @path       ||= 'backups'
        path.sub!(/^\//, '')
      end

      private

      def connection
        @connection ||= Fog::Storage.new(
          :provider             => 'Rackspace',
          :rackspace_username   => username,
          :rackspace_api_key    => api_key,
          :rackspace_auth_url   => auth_url,
          :rackspace_servicenet => servicenet
        )
      end

      def transfer!
        connection.put_container(container)

        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = File.join(remote_path, filename)
          Logger.info "Storing '#{ container }/#{ dest }'..."
          File.open(src, 'r') do |file|
            connection.put_object(container, dest, file)
          end
        end
      end

      # Called by the Cycler.
      # Any error raised will be logged as a warning.
      def remove!(package)
        Logger.info "Removing backup package dated #{ package.time }..."

        remote_path = remote_path_for(package)
        package.filenames.each do |filename|
          connection.delete_object(container, File.join(remote_path, filename))
        end
      end

    end
  end
end
