# encoding: utf-8

module Backup
  module Syncer
    module Cloud
      class CloudFiles < Base

        ##
        # Rackspace CloudFiles Credentials
        attr_accessor :api_key, :username

        ##
        # Rackspace CloudFiles Container
        attr_accessor :container

        ##
        # Rackspace AuthURL allows you to connect
        # to a different Rackspace datacenter
        # - https://auth.api.rackspacecloud.com     (Default: US)
        # - https://lon.auth.api.rackspacecloud.com (UK)
        attr_accessor :auth_url

        ##
        # Improve performance and avoid data transfer costs
        # by setting @servicenet to `true`
        # This only works if Backup runs on a Rackspace server
        attr_accessor :servicenet

        ##
        # Instantiates a new Cloud::CloudFiles Syncer.
        #
        # Pre-configured defaults specified in
        # Configuration::Syncer::Cloud::CloudFiles
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
        # Creates a new @repository_object (container).
        # Fetches it from Cloud Files if it already exists,
        # otherwise it will create it first and fetch use that instead.
        def repository_object
          @repository_object ||= connection.directories.get(container) ||
            connection.directories.create(:key => container)
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
