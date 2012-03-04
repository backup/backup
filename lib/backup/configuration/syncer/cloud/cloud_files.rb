# encoding: utf-8

module Backup
  module Configuration
    module Syncer
      module Cloud
        class CloudFiles < Base
          class << self

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

          end
        end
      end
    end
  end
end
