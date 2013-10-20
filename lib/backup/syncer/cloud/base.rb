# encoding: utf-8

module Backup
  module Syncer
    module Cloud
      class Error < Backup::Error; end

      class Base < Syncer::Base
        MUTEX = Mutex.new

        ##
        # Number of threads to use for concurrency.
        #
        # Default: 0 (no concurrency)
        attr_accessor :thread_count

        ##
        # Number of times to retry failed operations.
        #
        # Default: 10
        attr_accessor :max_retries

        ##
        # Time in seconds to pause before each retry.
        #
        # Default: 30
        attr_accessor :retry_waitsec

        def initialize(syncer_id = nil, &block)
          super
          instance_eval(&block) if block_given?

          @thread_count   ||= 0
          @max_retries    ||= 10
          @retry_waitsec  ||= 30

          @path ||= 'backups'
          @path = path.sub(/^\//, '')
        end

        def perform!
          log!(:started)
          @transfer_count = 0
          @unchanged_count = 0
          @skipped_count = 0
          @orphans = thread_count > 0 ? Queue.new : []

          directories.each {|dir| sync_directory(dir) }
          orphans_result = process_orphans

          Logger.info "\nSummary:"
          Logger.info "\s\sTransferred Files: #{ @transfer_count }"
          Logger.info "\s\s#{ orphans_result }"
          Logger.info "\s\sUnchanged Files: #{ @unchanged_count }"
          Logger.warn "\s\sSkipped Files: #{ @skipped_count }" if @skipped_count > 0
          log!(:finished)
        end

        private

        def sync_directory(dir)
          remote_base = File.join(path, File.basename(dir))
          Logger.info "Gathering remote data for '#{ remote_base }'..."
          remote_files = get_remote_files(remote_base)

          Logger.info("Gathering local data for '#{ File.expand_path(dir) }'...")
          local_files = LocalFile.find(dir, excludes)

          relative_paths = (local_files.keys | remote_files.keys).sort
          if relative_paths.empty?
            Logger.info 'No local or remote files found'
          else
            Logger.info 'Syncing...'
            sync_block = Proc.new do |relative_path|
              local_file  = local_files[relative_path]
              remote_md5  = remote_files[relative_path]
              remote_path = File.join(remote_base, relative_path)
              sync_file(local_file, remote_path, remote_md5)
            end

            if thread_count > 0
              sync_in_threads(relative_paths, sync_block)
            else
              relative_paths.each(&sync_block)
            end
          end
        end

        def sync_in_threads(relative_paths, sync_block)
          queue = Queue.new
          queue << relative_paths.shift until relative_paths.empty?
          num_threads = [thread_count, queue.size].min
          Logger.info "\s\sUsing #{ num_threads } Threads"
          threads = num_threads.times.map do
            Thread.new do
              loop do
                path = queue.shift(true) rescue nil
                path ? sync_block.call(path) : break
              end
            end
          end

          # abort if any thread raises an exception
          while threads.any?(&:alive?)
            if threads.any? {|thr| thr.status.nil? }
              threads.each(&:kill)
              Thread.pass while threads.any?(&:alive?)
              break
            end
            sleep num_threads * 0.1
          end
          threads.each(&:join)
        end

        # If an exception is raised in multiple threads, only the exception
        # raised in the first thread that Thread#join is called on will be
        # handled. So all exceptions are logged first with their details,
        # then a generic exception is raised.
        def sync_file(local_file, remote_path, remote_md5)
          if local_file && File.exist?(local_file.path)
            if local_file.md5 == remote_md5
              MUTEX.synchronize { @unchanged_count += 1 }
            else
              Logger.info("\s\s[transferring] '#{ remote_path }'")
              begin
                cloud_io.upload(local_file.path, remote_path)
                MUTEX.synchronize { @transfer_count += 1 }
              rescue CloudIO::FileSizeError => err
                MUTEX.synchronize { @skipped_count += 1 }
                Logger.warn Error.wrap(err, "Skipping '#{ remote_path }'")
              rescue => err
                Logger.error(err)
                raise Error, <<-EOS
                  Syncer Failed!
                  See the Retry [info] and [error] messages (if any)
                  for details on each failed operation.
                EOS
              end
            end
          elsif remote_md5
            @orphans << remote_path
          end
        end

        def process_orphans
          if @orphans.empty?
            return mirror ? 'Deleted Files: 0' : 'Orphaned Files: 0'
          end

          if @orphans.is_a?(Queue)
            @orphans = @orphans.size.times.map { @orphans.shift }
          end

          if mirror
            Logger.info @orphans.map {|path|
              "\s\s[removing] '#{ path }'"
            }.join("\n")

            begin
              cloud_io.delete(@orphans)
              "Deleted Files: #{ @orphans.count }"
            rescue => err
              Logger.warn Error.wrap(err, 'Delete Operation Failed')
              "Attempted to Delete: #{ @orphans.count } " +
              "(See log messages for actual results)"
            end
          else
            Logger.info @orphans.map {|path|
              "\s\s[orphaned] '#{ path }'"
            }.join("\n")
            "Orphaned Files: #{ @orphans.count }"
          end
        end

      end
    end
  end
end
