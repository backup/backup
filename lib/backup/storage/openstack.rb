# encoding: utf-8

##
# Only load the Fog gem when the Backup::Storage::OpenStack class is loaded
require 'fog'

module Backup
  module Storage
    class OpenStack < Base

      ##
      # OpenStack credentials
      attr_accessor :username, :api_key, :auth_url

      ##
      # OpenStack storage container name
      attr_accessor :container

      ##
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil, &block)
       super
        instance_eval(&block) if block_given?

        @path       ||= 'backups'
        path.sub!(/^\//, '')
      end

      protected

      ##
      # This is the provider that Fog uses
      def provider
        'OpenStack'
      end

      ##
      # Establishes a connection
      def connection
        @connection ||= Fog::Storage.new(
          :provider             => provider,
          :openstack_username   => username,
          :openstack_api_key    => api_key,
          :openstack_auth_url   => auth_url
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
