# encoding: utf-8

module Backup
  module Syncer
    module Cloud
      class HPCloud < Base

        ##
        # HPCloud Object Storage Service Credentials
        attr_accessor :hp_access_key, :hp_secret_key, :hp_tenant_id

        ##
        # HPCloud Object Storage Service Auth Url and Availability Zone
        attr_accessor :hp_auth_uri, :hp_avl_zone

        ##
        # HPCloud Object Storage container name
        attr_accessor :container

        ##
        # Instantiates a new Cloud::HPCloud Syncer.
        #
        # Pre-configured defaults specified in
        # Configuration::Syncer::Cloud::HPCloud
        # are set via a super() call to Cloud::Base,
        # which in turn will invoke Syncer::Base.
        #
        # Once pre-configured defaults and Cloud specific defaults are set,
        # the block from the user's configuration file is evaluated.
        def initialize(syncer_id = nil, &block)
          super

          instance_eval(&block) if block_given?
          @path = path.sub(/^\//, '')
        end

        private

        ##
        # Established and creates a new Fog storage object for S3.
        def connection
          @connection ||= Fog::Storage.new(
            :provider       => provider,
            :hp_access_key  => hp_access_key,
            :hp_secret_key  => hp_secret_key,
            :hp_auth_uri    => hp_auth_uri || "https://region-a.geo-1.identity.hpcloudsvc.com:35357/v2.0/tokens",
            :hp_tenant_id   => hp_tenant_id,
            :hp_avl_zone    => hp_avl_zone || "region-a.geo-1"
          )
        end

        ##
        # Creates a new @repository_object (container).
        # Fetches it from HPCloud if it already exists,
        # otherwise it will create it first and fetch use that instead.
        def repository_object
          @repository_object ||= connection.directories.get(container) ||
            connection.directories.create(:key => container)
        end

        ##
        # This is the provider that Fog uses for the HPCloud Object Storage
        def provider
          "HP"
        end

      end # Class HPCloud < Base
    end # module Cloud
  end
end
