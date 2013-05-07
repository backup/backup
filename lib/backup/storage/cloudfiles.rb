# encoding: utf-8
require 'fog'

module Backup
  module Storage
    class CloudFiles < OpenStack

      ##
      # Rackspace Service Net
      # (LAN-based transfers to avoid charges and improve performance)
      attr_accessor :servicenet

      def initialize(model, storage_id = nil, &block)
        super

        @servicenet ||= false
      end

      protected

      def connection
        @connection ||= Fog::Storage.new(
          :provider             => 'Rackspace',
          :rackspace_username   => username,
          :rackspace_api_key    => api_key,
          :rackspace_auth_url   => auth_url,
          :rackspace_servicenet => servicenet
        )
      end

    end
  end
end