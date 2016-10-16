# encoding: utf-8
require 'backup/cloud_io/base'
require 'fog/openstack'

LARGE_FILE = 5 * 1024**3 - 1

module Backup
  module CloudIO
    class Swift < Base
      class Error < Backup::Error; end
      Object = Fog::Storage::OpenStack::File

      attr_reader :username, :password, :tenant, :region,
                  :container, :auth_url, :max_retries,
                  :retry_waitsec, :fog_options, :batch_size

      def initialize(opts = {})
        super

        @username       = opts[:username]
        @password       = opts[:password]
        @tenant         = opts[:tenant_name]
        @container      = opts[:container]
        @auth_url       = opts[:auth_url]
        @region         = opts[:region]
        @max_retries    = opts[:max_retries]
        @retry_waitsec  = opts[:retry_waitsec]
        @batch_size     = opts[:batch_size]
        @fog_options    = opts[:fog_options]
      end

      def upload(src, dest)
        file_size = File.size(src)

        raise FileSizeError, <<-EOS if file_size > LARGE_FILE
          [FIXME] File Too Large
          File: #{ src }
          Size: #{ file_size }
          Max Swift Upload Size is #{ LARGE_FILE } (5 Gb) (FIXME)
        EOS

        directory.files.create key: dest, body: File.open(src)
      end

      def delete(objects_or_keys)
        keys = Array(objects_or_keys).dup
        keys = keys.map(&:key) unless keys.first.is_a?(String)

        until keys.empty?
          _k = keys.slice!(0, batch_size)
          with_retries('DELETE Multiple Objects') do
            resp = connection.delete_multiple_objects(container, _k)
            if resp.data[:status] != 200
              raise Error, <<-EOS
                Failed to delete.
                Status = #{resp.data[:status]}
                Reason = #{resp.data[:reason_phrase]}
                Body = #{resp.data[:body]}
              EOS
            end
          end
        end
      end

      def objects(prefix)
        directory.files.all(prefix: prefix.chomp('/') + '/')
      end

      private

      def directory
        @directory ||= connection.directories.get container
      end

      def connection
        @connection ||= begin
          opts = {
            provider: 'OpenStack',
            openstack_auth_url: auth_url,
            openstack_username: username,
            openstack_api_key: password,
          }
          opts[:openstack_region] = region unless region.nil?
          opts[:openstack_tenant] = tenant unless tenant.nil?

          opts.merge!(fog_options || {})
          Fog::Storage.new(opts)
        end
      end

    end
  end
end
