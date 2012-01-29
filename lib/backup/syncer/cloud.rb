# encoding: utf-8

##
# Only load the Fog gem when the Backup::Syncer::Cloud class is loaded
Backup::Dependency.load('fog')

module Backup
  module Syncer
    class Cloud < Base
      ##
      # Bucket/container name
      attr_accessor :bucket

      ##
      # Parallelize setting - defaults to false, but can be set to :threads or
      # :processors
      attr_accessor :parallelize

      ##
      # Parallel count - the number of threads or processors to use. Defaults to
      # 2.
      attr_accessor :parallel_count

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
        @parallelize          = false
        @parallel_count       = 2

        instance_eval(&block) if block_given?

        @path = path.sub(/^\//, '')
      end

      ##
      # Performs the Sync operation
      def perform!
        Logger.message("#{ self.class } started syncing.")

        directories.each do |directory|
          SyncContext.new(directory, bucket_object, path).sync! mirror
        end
      end

      private

      def connection
        raise "Should be implemented by the subclass"
      end

      def bucket_object
        @bucket_object ||= connection.directories.get(bucket) ||
          connection.directories.create(:key => bucket)
      end

      class SyncContext
        attr_reader :directory, :bucket, :path

        def initialize(directory, bucket, path)
          @directory, @bucket, @path = directory, bucket, path
        end

        def sync!(mirror = false)
          all_file_names.each do |relative_path|
            local_file  = local_files[relative_path]
            remote_file = remote_files[relative_path]

            if local_file && File.exist?(local_file.path)
              bucket.files.create(
                :key  => "#{path}/#{relative_path}".gsub(/^\//, ''),
                :body => File.open(local_file.path)
              ) unless remote_file && remote_file.etag == local_file.md5
            elsif mirror
              remote_file.destroy
            end
          end
        end

        private

        def all_file_names
          @all_file_names ||= (local_files.keys | remote_files.keys).sort
        end

        def local_files
          @local_files ||= begin
            local_hashes.split("\n").collect { |line|
              LocalFile.new directory, line
            }.inject({}) { |hash, file|
              hash[file.relative_path] = file
              hash
            }
          end
        end

        def remote_files
          @remote_files ||= bucket.files.select { |file|
            file.key[/^#{path}\/#{directory.split('/').first}\//]
          }.inject({}) { |hash, file|
            hash[file.key.gsub(/^#{path}\//, '')] = file
            hash
          }
        end

        def local_hashes
          `find #{directory} -print0 | xargs -0 openssl md5 2> /dev/null`
        end
      end

      class LocalFile
        attr_reader :directory, :path, :md5

        def initialize(directory, line)
          @directory  = directory
          @path, @md5 = *line.chomp.match(/^MD5\(([^\)]+)\)= (\w+)$/).captures
        end

        def relative_path
          @relative_path ||= path.gsub %r{^#{directory}},
            directory.split('/').last
        end
      end
    end
  end
end
