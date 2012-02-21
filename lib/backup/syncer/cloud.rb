# encoding: utf-8

##
# Only load the Fog gem, along with the Parallel gem, when the Backup::Syncer::Cloud class is loaded
Backup::Dependency.load('fog')
Backup::Dependency.load('parallel')

module Backup
  module Syncer
    class Cloud < Base

      ##
      # Create a Mutex to synchronize certain parts of the code
      # in order to prevent race conditions or broken STDOUT.
      MUTEX = Mutex.new

      ##
      # Concurrency setting - defaults to false, but can be set to:
      # - :threads
      # - :processes
      attr_accessor :concurrency_type

      ##
      # Concurrency level - the number of threads or processors to use. Defaults to 2.
      attr_accessor :concurrency_level

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
        @concurrency_type     = false
        @concurrency_level    = 2

        instance_eval(&block) if block_given?

        @path = path.sub(/^\//, '')
      end

      ##
      # Performs the Sync operation
      def perform!
        Logger.message("#{ syncer_name } started the syncing process:")

        directories.each do |directory|
          SyncContext.new(directory, repository_object, path).
            sync! mirror, concurrency_type, concurrency_level
        end
      end

      private

      class SyncContext
        attr_reader :directory, :bucket, :path

        ##
        # Creates a new SyncContext object which handles a single directory
        # from the Syncer::Base @directories array.
        def initialize(directory, bucket, path)
          @directory, @bucket, @path = directory, bucket, path
        end

        ##
        # Performs the sync operation using the provided techniques (mirroring/concurrency).
        def sync!(mirror = false, concurrency_type = false, concurrency_level = 2)
          block = Proc.new { |relative_path| sync_file relative_path, mirror }

          case concurrency_type
          when FalseClass
            all_file_names.each &block
          when :threads
            Parallel.each all_file_names, :in_threads => concurrency_level, &block
          when :processes
            Parallel.each all_file_names, :in_processes => concurrency_level, &block
          else
            raise Errors::Syncer::Cloud::ConfigurationError,
                "Unknown concurrency_type setting: #{concurrency_type.inspect}"
          end
        end

        private

        ##
        # Gathers all the remote and local file name and merges them together, removing
        # duplicate keys if any, and sorts the in alphabetical order.
        def all_file_names
          @all_file_names ||= (local_files.keys | remote_files.keys).sort
        end

        ##
        # Returns a Hash of local files (the keys are the filesystem paths,
        # the values are the LocalFile objects for that given file)
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

        ##
        # Returns a String of file paths and their md5 hashes.
        def local_hashes
          MUTEX.synchronize { Logger.message("\s\sGenerating checksums for #{ directory }") }
          `find #{directory} -print0 | xargs -0 openssl md5 2> /dev/null`
        end

        ##
        # Returns a Hash of remote files (the keys are the remote paths,
        # the values are the Fog file objects for that given file)
        def remote_files
          @remote_files ||= bucket.files.to_a.select { |file|
            file.key[%r{^#{remote_base}/}]
          }.inject({}) { |hash, file|
            key = file.key.gsub(/^#{remote_base}\//,
              "#{directory.split('/').last}/")
            hash[key] = file
            hash
          }
        end

        ##
        # Creates and returns a String that represents the base remote storage path
        def remote_base
          @remote_base ||= [path, directory.split('/').last].select { |part|
            part && part.strip.length > 0
          }.join('/')
        end

        ##
        # Performs a sync operation on a file. When mirroring is enabled
        # and a local file has been removed since the last sync, it will also
        # remove it from the remote location. It will no upload files that
        # have not changed since the last sync. Checks are done using an md5 hash.
        # If a file has changed, or has been newly added, the file will be transferred/overwritten.
        def sync_file(relative_path, mirror)
          local_file  = local_files[relative_path]
          remote_file = remote_files[relative_path]

          if local_file && File.exist?(local_file.path)
            unless remote_file && remote_file.etag == local_file.md5
              MUTEX.synchronize { Logger.message("\s\s[transferring] #{relative_path}") }
              File.open(local_file.path, 'r') do |file|
                bucket.files.create(
                  :key  => "#{path}/#{relative_path}".gsub(/^\//, ''),
                  :body => file
                )
              end
            else
              MUTEX.synchronize { Logger.message("\s\s[skipping] #{relative_path}") }
            end
          elsif remote_file && mirror
            MUTEX.synchronize { Logger.message("\s\s[removing] #{relative_path}") }
            remote_file.destroy
          end
        end
      end

      class LocalFile
        attr_reader :directory, :path, :md5

        ##
        # Creates a new LocalFile object using the given directory and line
        # from the md5 hash checkup. This object figures out the path, relative_path and md5 hash
        # for the file.
        def initialize(directory, line)
          @directory  = directory
          @path, @md5 = *line.chomp.match(/^MD5\(([^\)]+)\)= (\w+)$/).captures
        end

        ##
        # Returns the relative path to the file.
        def relative_path
          @relative_path ||= path.gsub %r{^#{directory}},
            directory.split('/').last
        end
      end
    end
  end
end
