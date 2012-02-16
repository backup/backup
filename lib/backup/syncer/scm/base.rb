# encoding: utf-8

module Backup
  module Syncer
    module SCM
      class Base < Syncer::Base

        ##
        # In a server url such as:
        #    https://jimmy:password@example.com:80
        # -> [protocol]://[username]:[password][ip]:[port]
        attr_accessor :protocol, :username, :password, :ip, :port

        ##
        # repositories is an alias to directories; provided just for clarity
        alias :repositories  :directories
        alias :repositories= :directories=

        ##
        # Instantiates a new Repository Syncer object
        # and sets the default configuration
        def initialize
          load_defaults!

          @path               ||= 'backups'
          @directories          = Array.new
        end

        def perform!
          Logger.message("#{ self.class } started syncing '#{ path }'.")
          repositories.each do |repository|
            backup_repository! repository
          end
        end

        def authority
          "#{protocol}://#{credentials}#{ip}#{prefixed_port}"
        end

        def repository_urls
          repositories.collect{ |r| repository_url(r) }
        end

        def repository_url(repository)
          "#{authority}#{repository}"
        end

        def repository_local_path(repository)
          File.join(path, repository)
        end

        def repository_absolute_local_path(repository)
          File.absolute_path(repository_local_path(repository))
        end

        def repository_local_container_path(repository)
          File.dirname(repository_local_path(repository)) 
        end

        def create_repository_local_container!(repository)
          FileUtils.mkdir_p(repository_local_container_path(repository))
        end

        private

        def credentials
          "#{username}#{prefixed_password}@" if username
        end

        def prefixed_password
          ":#{password}" if password
        end

        def prefixed_port
          ":#{port}" if port
        end
      end
    end
  end
end
