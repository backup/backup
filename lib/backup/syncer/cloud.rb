# encoding: utf-8

##
# Only load the Fog gem when the Backup::Syncer::Cloud class is loaded
Backup::Dependency.load('fog')

module Backup
  module Syncer
    class Cloud < Base
      ##
      # Bucket/container name and path to sync to
      attr_accessor :bucket, :path

      ##
      # Directories to sync
      attr_accessor :directories

      ##
      # Flag to enable mirroring - currently ignored.
      attr_accessor :mirror

      ##
      # Instantiates a new Cloud Syncer object and sets the default
      # configuration specified in the Backup::Configuration::Syncer::S3. Then
      # it sets the object defaults if particular properties weren't set.
      # Finally it'll evaluate the users configuration file and overwrite
      # anything that's been defined.
      def initialize(&block)
        load_defaults!

        @path               ||= 'backups'
        @directories        ||= Array.new
        @mirror             ||= false

        instance_eval(&block) if block_given?

        @path = path.sub(/^\//, '')
      end

      ##
      # Performs the Sync operation
      def perform!
        directories.each do |directory|
          Logger.message("#{ self.class } started syncing '#{ directory }'.")

          hashes_for_directory(directory).each do |full_path, md5|
            next unless File.exist?(full_path)

            relative_path = full_path.gsub %r{^#{directory}},
              directory.split('/').last
            remote_path   = "#{path}/#{relative_path}".gsub(/^\//, '')

            bucket_object.files.create(
              :key  => remote_path,
              :body => File.open(full_path)
            ) unless remote_hashes[remote_path] == md5
          end
        end
      end

      ##
      # Syntactical suger for the DSL for adding directories
      def directories(&block)
        return @directories unless block_given?
        instance_eval(&block)
      end

      ##
      # Adds a path to the @directories array
      def add(path)
        @directories << path
      end

      private

      def connection
        raise "Should be implemented by the subclass"
      end

      def bucket_object
        @bucket_object ||= connection.directories.get(bucket) ||
          connection.directories.create(:key => bucket)
      end

      def hashes_for_directory(directory)
        hashes = `find #{directory} -print0 | xargs -0 openssl md5 2> /dev/null`
        hashes.split("\n").inject({}) do |hash, line|
          path, md5 = *line.chomp.match(/^MD5\(([^\)]+)\)= (\w+)$/).captures
          hash[path] = md5
          hash
        end
      end

      def remote_hashes
        @remote_hashes ||= bucket_object.files.inject({}) { |hash, file|
          hash[file.key] = file.etag
          hash
        }
      end
    end
  end
end
