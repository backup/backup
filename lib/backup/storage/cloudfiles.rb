# encoding: utf-8

module Backup
  module Storage
    class CloudFiles < OpenStack

      ##
      # Rackspace Service Net
      # (LAN-based transfers to avoid charges and improve performance)
      attr_accessor :servicenet

      ##
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil, &block)
        super(model, storage_id)

        @servicenet ||= false
      end

      protected

      ##
      # This is the provider that Fog uses for the Cloud Files Storage
      def provider
        'Rackspace'
      end

      ##
      # Establishes a connection to Rackspace Cloud Files
      def connection
        @connection ||= Fog::Storage.new(
          :provider             => provider,
          :rackspace_username   => username,
          :rackspace_api_key    => api_key,
          :rackspace_auth_url   => auth_url,
          :rackspace_servicenet => servicenet
        )
      end
    end
  end
end
