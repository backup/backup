# encoding: utf-8
require 'backup/cloud_io/base'
require 'fog'
require 'digest/md5'

module Backup
  module CloudIO
    class CloudFiles < Base
      class Error < Backup::Error; end

      MAX_FILE_SIZE   = 1024**3 * 5     # 5 GiB
      MAX_SLO_SIZE    = 1024**3 * 5000  # 1000 segments @ 5 GiB
      SEGMENT_BUFFER  = 1024**2         # 1 MiB

      attr_reader :username, :api_key, :auth_url, :region, :servicenet,
                  :container, :segments_container, :segment_size, :days_to_keep,
                  :fog_options

      def initialize(options = {})
        super

        @username           = options[:username]
        @api_key            = options[:api_key]
        @auth_url           = options[:auth_url]
        @region             = options[:region]
        @servicenet         = options[:servicenet]
        @container          = options[:container]
        @segments_container = options[:segments_container]
        @segment_size       = options[:segment_size]
        @days_to_keep       = options[:days_to_keep]
        @fog_options        = options[:fog_options]
      end

      # The Syncer may call this method in multiple threads,
      # but #objects is always called before this occurs.
      def upload(src, dest)
        create_containers

        file_size = File.size(src)
        segment_bytes = segment_size * 1024**2
        if segment_bytes > 0 && file_size > segment_bytes
          raise FileSizeError, <<-EOS if file_size > MAX_SLO_SIZE
            File Too Large
            File: #{ src }
            Size: #{ file_size }
            Max SLO Size is #{ MAX_SLO_SIZE } (5 GiB * 1000 segments)
          EOS

          segment_bytes = adjusted_segment_bytes(segment_bytes, file_size)
          segments = upload_segments(src, dest, segment_bytes, file_size)
          upload_manifest(dest, segments)
        else
          raise FileSizeError, <<-EOS if file_size > MAX_FILE_SIZE
            File Too Large
            File: #{ src }
            Size: #{ file_size }
            Max File Size is #{ MAX_FILE_SIZE } (5 GiB)
          EOS

          put_object(src, dest)
        end
      end

      # Returns all objects in the container with the given prefix.
      #
      # - #get_container returns a max of 10000 objects per request.
      # - Returns objects sorted using a sqlite binary collating function.
      # - If marker is given, only objects after the marker are in the response.
      def objects(prefix)
        objects = []
        resp = nil
        prefix = prefix.chomp('/')
        opts = { :prefix => prefix + '/' }

        create_containers

        while resp.nil? || resp.body.count == 10000
          opts.merge!(:marker => objects.last.name) unless objects.empty?
          with_retries("GET '#{ container }/#{ prefix }/*'") do
            resp = connection.get_container(container, opts)
          end
          resp.body.each do |obj_data|
            objects << Object.new(self, obj_data)
          end
        end

        objects
      end

      # Used by Object to fetch metadata if needed.
      def head_object(object)
        resp = nil
        with_retries("HEAD '#{ container }/#{ object.name }'") do
          resp = connection.head_object(container, object.name)
        end
        resp
      end

      # Delete non-SLO object(s) from the container.
      #
      # - Called by the Storage (with objects) and the Syncer (with names)
      # - Deletes 10,000 objects per request.
      # - Missing objects will be ignored.
      def delete(objects_or_names)
        names = Array(objects_or_names).dup
        names.map!(&:name) if names.first.is_a?(Object)

        until names.empty?
          _names = names.slice!(0, 10000)
          with_retries('DELETE Multiple Objects') do
            resp = connection.delete_multiple_objects(container, _names)
            resp_status = resp.body['Response Status']
            raise Error, <<-EOS unless resp_status == '200 OK'
              #{ resp_status }
              The server returned the following:
              #{ resp.body.inspect }
            EOS
          end
        end
      end

      # Delete an SLO object(s) from the container.
      #
      # - Used only by the Storage. The Syncer cannot use SLOs.
      # - Removes the SLO manifest object and all associated segments.
      # - Missing segments will be ignored.
      def delete_slo(objects)
        Array(objects).each do |object|
          with_retries("DELETE SLO Manifest '#{ container }/#{ object.name }'") do
            resp = connection.delete_static_large_object(container, object.name)
            resp_status = resp.body['Response Status']
            raise Error, <<-EOS unless resp_status == '200 OK'
              #{ resp_status }
              The server returned the following:
              #{ resp.body.inspect }
            EOS
          end
        end
      end

      private

      def connection
        @connection ||= Fog::Storage.new({
          :provider             => 'Rackspace',
          :rackspace_username   => username,
          :rackspace_api_key    => api_key,
          :rackspace_auth_url   => auth_url,
          :rackspace_region     => region,
          :rackspace_servicenet => servicenet
        }.merge(fog_options || {}))
      end

      def create_containers
        return if @containers_created
        @containers_created = true

        with_retries('Create Containers') do
          connection.put_container(container)
          connection.put_container(segments_container) if segments_container
        end
      end

      def put_object(src, dest)
        opts = headers.merge('ETag' => Digest::MD5.file(src).hexdigest)
        with_retries("PUT '#{ container }/#{ dest }'") do
          File.open(src, 'r') do |file|
            connection.put_object(container, dest, file, opts)
          end
        end
      end

      # Each segment is uploaded using chunked transfer encoding using
      # SEGMENT_BUFFER, and each segment's MD5 is sent to verify the transfer.
      # Each segment's MD5 and byte_size will also be verified when the
      # SLO manifest object is uploaded.
      def upload_segments(src, dest, segment_bytes, file_size)
        total_segments = (file_size / segment_bytes.to_f).ceil
        progress = (0.1..0.9).step(0.1).map {|n| (total_segments * n).floor }
        Logger.info "\s\sUploading #{ total_segments } SLO Segments..."

        segments = []
        File.open(src, 'r') do |file|
          segment_number = 0
          until file.eof?
            segment_number += 1
            object = "#{ dest }/#{ segment_number.to_s.rjust(4, '0') }"
            pos = file.pos
            md5 = segment_md5(file, segment_bytes)
            opts = headers.merge('ETag' => md5)

            with_retries("PUT '#{ segments_container }/#{ object }'") do
              file.seek(pos)
              offset = 0
              connection.put_object(segments_container, object, nil, opts) do
                # block is called to stream data until it returns ''
                data = ''
                if offset <= segment_bytes - SEGMENT_BUFFER
                  data = file.read(SEGMENT_BUFFER).to_s # nil => ''
                  offset += data.size
                end
                data
              end
            end

            segments << {
              :path => "#{ segments_container }/#{ object }",
              :etag => md5,
              :size_bytes => file.pos - pos
            }

            if i = progress.rindex(segment_number)
              Logger.info "\s\s...#{ i + 1 }0% Complete..."
            end
          end
        end
        segments
      end

      def segment_md5(file, segment_bytes)
        md5 = Digest::MD5.new
        offset = 0
        while offset <= segment_bytes - SEGMENT_BUFFER
          data = file.read(SEGMENT_BUFFER)
          break unless data
          offset += data.size
          md5 << data
        end
        md5.hexdigest
      end

      # Each segment's ETag and byte_size will be verified once uploaded.
      # Request will raise an exception if verification fails or segments
      # are not found. However, each segment's ETag was verified when we
      # uploaded the segments, so this should only retry failed requests.
      def upload_manifest(dest, segments)
        Logger.info "\s\sStoring SLO Manifest '#{ container }/#{ dest }'"

        with_retries("PUT SLO Manifest '#{ container }/#{ dest }'") do
          connection.put_static_obj_manifest(container, dest, segments, headers)
        end
      end

      # If :days_to_keep was set, each object will be scheduled for deletion.
      # This includes non-SLO objects, the SLO manifest and all segments.
      def headers
        headers = {}
        headers.merge!('X-Delete-At' => delete_at) if delete_at
        headers
      end

      def delete_at
        return unless days_to_keep
        @delete_at ||= (Time.now.utc + days_to_keep * 60**2 * 24).to_i
      end

      def adjusted_segment_bytes(segment_bytes, file_size)
        return segment_bytes if file_size / segment_bytes.to_f <= 1000

        mb = orig_mb = segment_bytes / 1024**2
        mb += 1 until file_size / (1024**2 * mb).to_f <= 1000
        Logger.warn Error.new(<<-EOS)
          Segment Size Adjusted
          Your original #segment_size of #{ orig_mb } MiB has been adjusted
          to #{ mb } MiB in order to satisfy the limit of 1000 segments.
          To enforce your chosen #segment_size, you should use the Splitter.
          e.g. split_into_chunks_of #{ mb * 1000 } (#segment_size * 1000)
        EOS
        1024**2 * mb
      end

      class Object
        attr_reader :name, :hash

        def initialize(cloud_io, data)
          @cloud_io = cloud_io
          @name = data['name']
          @hash = data['hash']
        end

        def slo?
          !!metadata['X-Static-Large-Object']
        end

        def marked_for_deletion?
          !!metadata['X-Delete-At']
        end

        private

        def metadata
          @metadata ||= @cloud_io.head_object(self).headers
        end
      end

    end
  end
end
