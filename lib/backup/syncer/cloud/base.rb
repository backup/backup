# encoding: utf-8

##
# Only load the Fog gem, along with the Parallel gem, when the
# Backup::Syncer::Cloud class is loaded
# Backup::Dependency.load('fog')
# Backup::Dependency.load('parallel')
require 'fog'
require 'parallel'

module Backup
  module Syncer
    module Cloud
      class Base < Syncer::Base

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
        # Concurrency level - the number of threads or processors to use.
        # Defaults to 2.
        attr_accessor :concurrency_level

        ##
        # Instantiates a new Cloud Syncer object for either
        # the Cloud::S3 or Cloud::CloudFiles Syncer.
        #
        # Pre-configured defaults specified in either
        # Configuration::Syncer::Cloud::S3 or
        # Configuration::Syncer::Cloud::CloudFiles
        # are set via a super() call to Syncer::Base.
        #
        # If not specified in the pre-configured defaults,
        # the Cloud specific defaults are set here before evaluating
        # any block provided in the user's configuration file.
        def initialize(syncer_id = nil)
          super

          @path = path.sub(/^~\//, '')
          @concurrency_type  ||= false
          @concurrency_level ||= 2
        end

        ##
        # Performs the Sync operation
        def perform!
          log!(:started)
          Logger.info(
            "\s\sConcurrency: #{ @concurrency_type } Level: #{ @concurrency_level }"
          )

          @directories.each do |directory|
            SyncContext.new(
              File.expand_path(directory), repository_object, @path
            ).sync! @mirror, @concurrency_type, @concurrency_level
          end

          log!(:finished)
        end

        private

        class SyncContext
          include Utilities::Helpers

          attr_reader :directory, :bucket, :path, :remote_base

          ##
          # Creates a new SyncContext object which handles a single directory
          # from the Syncer::Base @directories array.
          def initialize(directory, bucket, path)
            @directory, @bucket, @path = directory, bucket, path
            @remote_base = File.join(path, File.basename(directory))
          end

          ##
          # Performs the sync operation using the provided techniques
          # (mirroring/concurrency).
          def sync!(mirror = false, concurrency_type = false, concurrency_level = 2)
            block = Proc.new { |relative_path| sync_file relative_path, mirror }

            case concurrency_type
            when FalseClass
              all_file_names.each(&block)
            when :threads
              Parallel.each all_file_names,
                  :in_threads => concurrency_level, &block
            when :processes
              Parallel.each all_file_names,
                  :in_processes => concurrency_level, &block
            else
              raise Errors::Syncer::Cloud::ConfigurationError,
                  "Unknown concurrency_type setting: #{ concurrency_type.inspect }"
            end
          end

          private

          ##
          # Gathers all the relative paths to the local files
          # and merges them with the , removing
          # duplicate keys if any, and sorts the in alphabetical order.
          def all_file_names
            @all_file_names ||= (local_files.keys | remote_files.keys).sort
          end

          ##
          # Returns a Hash of local files, validated to ensure the path
          # does not contain invalid UTF-8 byte sequences.
          # The keys are the filesystem paths, relative to @directory.
          # The values are the LocalFile objects for that given file.
          def local_files
            @local_files ||= begin
              hash = {}
              local_hashes.lines.map do |line|
                LocalFile.new(@directory, line)
              end.compact.each do |file|
                hash.merge!(file.relative_path => file)
              end
              hash
            end
          end

          ##
          # Returns a String of file paths and their md5 hashes.
          #
          # Utilities#run is not used here because this would produce too much
          # log output, and Pipeline does not support capturing output.
          def local_hashes
            Logger.info("\s\sGenerating checksums for '#{ @directory }'")
            cmd = "#{ utility(:find) } -L '#{ @directory }' -type f -print0 | " +
                "#{ utility(:xargs) } -0 #{ utility(:openssl) } md5 2> /dev/null"
            %x[#{ cmd }]
          end

          ##
          # Returns a Hash of remote files
          # The keys are the remote paths, relative to @remote_base
          # The values are the Fog file objects for that given file
          def remote_files
            @remote_files ||= begin
              hash = {}
              @bucket.files.all(:prefix => @remote_base).each do |file|
                hash.merge!(file.key.sub("#{ @remote_base }/", '') => file)
              end
              hash
            end
          end

          ##
          # Performs a sync operation on a file. When mirroring is enabled
          # and a local file has been removed since the last sync, it will also
          # remove it from the remote location. It will no upload files that
          # have not changed since the last sync. Checks are done using an md5
          # hash. If a file has changed, or has been newly added, the file will
          # be transferred/overwritten.
          def sync_file(relative_path, mirror)
            local_file  = local_files[relative_path]
            remote_file = remote_files[relative_path]
            remote_path = File.join(@remote_base, relative_path)

            if local_file && File.exist?(local_file.path)
              unless remote_file && remote_file.etag == local_file.md5
                MUTEX.synchronize {
                  Logger.info("\s\s[transferring] '#{ remote_path }'")
                }
                File.open(local_file.path, 'r') do |file|
                  @bucket.files.create(
                    :key  => remote_path,
                    :body => file
                  )
                end
              else
                MUTEX.synchronize {
                  Logger.info("\s\s[skipping] '#{ remote_path }'")
                }
              end
            elsif remote_file
              if mirror
                MUTEX.synchronize {
                  Logger.info("\s\s[removing] '#{ remote_path }'")
                }
                remote_file.destroy
              else
                MUTEX.synchronize {
                  Logger.info("\s\s[leaving] '#{ remote_path }'")
                }
              end
            end
          end
        end # class SyncContext

        class LocalFile
          attr_reader :path, :relative_path, :md5

          ##
          # Return a new LocalFile object if it's valid.
          # Otherwise, log a warning and return nil.
          def self.new(*args)
            local_file = super(*args)
            if local_file.invalid?
              Logger.warn(
                "\s\s[skipping] #{ local_file.path }\n" +
                "\s\sPath Contains Invalid UTF-8 byte sequences"
              )
              return nil
            end
            local_file
          end

          ##
          # Creates a new LocalFile object using the given directory and line
          # from the md5 hash checkup. This object figures out the path,
          # relative_path and md5 hash for the file.
          def initialize(directory, line)
            @invalid = false
            @directory = sanitize(directory)
            line = sanitize(line).chomp
            @path = line.slice(4..-36)
            @md5 = line.slice(-32..-1)
            @relative_path = @path.sub(@directory + '/', '')
          end

          def invalid?
            @invalid
          end

          private

          ##
          # Sanitize string and replace any invalid UTF-8 characters.
          # If replacements are made, flag the LocalFile object as invalid.
          def sanitize(str)
            str.each_char.map do |char|
              begin
                char if !!char.unpack('U')
              rescue
                @invalid = true
                "\xEF\xBF\xBD" # => "\uFFFD"
              end
            end.join
          end

        end # class LocalFile

      end # class Base < Syncer::Base
    end # module Cloud
  end
end
