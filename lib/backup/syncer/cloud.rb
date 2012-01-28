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
        Logger.message("#{ self.class } started syncing.")

        hashes_for_directories.each do |file|
          next unless ::File.exist?(file.path)

          relative_path = file.path.gsub %r{^#{file.directory}},
            file.directory.split('/').last
          remote_path   = "#{path}/#{relative_path}".gsub(/^\//, '')
          remote_file   = remote_hashes[remote_path]

          bucket_object.files.create(
            :key  => remote_path,
            :body => ::File.open(file.path)
          ) unless remote_file && remote_file.etag == file.md5
        end

        remote_hashes.each do |remote_path, file|
          directory = directories.detect { |directory|
            remote_path[/^#{path}\/#{directory.split('/').last}\//]
          }
          return if directory.nil?
          local_path = remote_path.gsub(/^#{path}\/#{directory.split('/').last}/, directory)
          return if ::File.exist?(local_path)

          file.destroy
        end if mirror
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

      def hashes_for_directories
        @hashes_for_directories ||= directories.collect { |directory|
          hashes_for_directory directory
        }.flatten
      end

      def hashes_for_directory(directory)
        hashes = `find #{directory} -print0 | xargs -0 openssl md5 2> /dev/null`
        hashes.split("\n").collect { |line| File.new directory, line }
      end

      def remote_hashes
        @remote_hashes ||= bucket_object.files.inject({}) { |hash, file|
          hash[file.key] = file
          hash
        }
      end

      class File
        attr_reader :directory, :path, :md5

        def initialize(directory, line)
          @directory  = directory
          @path, @md5 = *line.chomp.match(/^MD5\(([^\)]+)\)= (\w+)$/).captures
        end
      end
    end
  end
end
