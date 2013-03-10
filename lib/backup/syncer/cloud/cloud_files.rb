# encoding: utf-8

module Backup
  module Syncer
    module Cloud
      class CloudFiles < OpenStack

        ##
        # Improve performance and avoid data transfer costs
        # by setting @servicenet to `true`
        # This only works if Backup runs on a Rackspace server
        attr_accessor :servicenet

        protected

        ##
        # Established and creates a new Fog storage object for CloudFiles.
        def connection
          @connection ||= Fog::Storage.new(
            :provider             => provider,
            :rackspace_username   => username,
            :rackspace_api_key    => api_key,
            :rackspace_auth_url   => auth_url,
            :rackspace_servicenet => servicenet
          )
        end

        ##
        # This is the provider that Fog uses for the Cloud Files
        def provider
          "Rackspace"
        end

      end # class Cloudfiles < Base
    end # module Cloud
  end
end
