# encoding: utf-8
require 'backup/cloud_io/cloud_files'

module Backup
  module Syncer
    module Cloud
      class CloudFiles < Base
        class Error < Backup::Error; end

        ##
        # Rackspace CloudFiles Credentials
        attr_accessor :username, :api_key

        ##
        # Rackspace CloudFiles Container
        attr_accessor :container

        ##
        # Rackspace AuthURL (optional)
        attr_accessor :auth_url

        ##
        # Rackspace Region (optional)
        attr_accessor :region

        ##
        # Rackspace Service Net
        # (LAN-based transfers to avoid charges and improve performance)
        attr_accessor :servicenet

        ##
        # Additional options to pass along to fog.
        # e.g. Fog::Storage.new({ :provider => 'Rackspace' }.merge(fog_options))
        attr_accessor :fog_options

        def initialize(syncer_id = nil)
          super

          @servicenet ||= false

          check_configuration
        end

        private

        def cloud_io
          @cloud_io ||= CloudIO::CloudFiles.new(
            :username           => username,
            :api_key            => api_key,
            :auth_url           => auth_url,
            :region             => region,
            :servicenet         => servicenet,
            :container          => container,
            :max_retries        => max_retries,
            :retry_waitsec      => retry_waitsec,
            # Syncer can not use SLOs.
            :segments_container => nil,
            :segment_size       => 0,
            :fog_options        => fog_options
          )
        end

        def get_remote_files(remote_base)
          hash = {}
          cloud_io.objects(remote_base).each do |object|
            relative_path = object.name.sub(remote_base + '/', '')
            hash[relative_path] = object.hash
          end
          hash
        end

        def check_configuration
          required = %w{ username api_key container }
          raise Error, <<-EOS if required.map {|name| send(name) }.any?(&:nil?)
            Configuration Error
            #{ required.map {|name| "##{ name }"}.join(', ') } are all required
          EOS
        end

        attr_deprecate :concurrency_type, :version => '3.7.0',
                       :message => 'Use #thread_count instead.',
                       :action => lambda {|klass, val|
                         if val == :threads
                           klass.thread_count = 2 unless klass.thread_count
                         else
                           klass.thread_count = 0
                         end
                       }

        attr_deprecate :concurrency_level, :version => '3.7.0',
                       :message => 'Use #thread_count instead.',
                       :action => lambda {|klass, val|
                         klass.thread_count = val unless klass.thread_count == 0
                       }

      end # class Cloudfiles < Base
    end # module Cloud
  end
end
