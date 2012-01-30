# encoding: utf-8

##
# Only load the Fog gem when the Backup::Syncer::Rackspace class is loaded
Backup::Dependency.load('fog')

module Backup
  module Syncer
    class Rackspace < Cloud
      ##
      # Rackspace CloudFiles Credentials
      attr_accessor :api_key, :username, :auth_url

      private

      def connection
        @connection ||= Fog::Storage.new(
          :provider           => 'Rackspace',
          :rackspace_api_key  => api_key,
          :rackspace_username => username,
          :rackspace_auth_url => auth_url
        )
      end
    end
  end
end
