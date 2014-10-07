# encoding: utf-8
require 'backup/cloud_io/dropbox'

module Backup
  module Syncer
    module Cloud
      class Dropbox < Base
        include Storage::Cycler
        class Error < Backup::Error;
        end

        ##
        # Dropbox API credentials
        attr_accessor :api_key, :api_secret

        ##
        # Path to store cached authorized session.
        #
        # Relative paths will be expanded using Config.root_path,
        # which by default is ~/Backup unless --root-path was used
        # on the command line or set in config.rb.
        #
        # By default, +cache_path+ is '.cache', which would be
        # '~/Backup/.cache/' if using the default root_path.
        attr_accessor :cache_path

        ##
        # Dropbox Access Type
        # Valid values are:
        #   :app_folder (default)
        #   :dropbox (full access)
        attr_accessor :access_type

        ##
        # Chunk size, specified in MiB, for the ChunkedUploader.
        attr_accessor :chunk_size

        ##
        # Creates a new instance of the storage object
        def initialize(syncer_id = nil)
          super

          @cache_path  ||= '.cache'
          @access_type ||= :app_folder
          @chunk_size  ||= 4 # MiB

          check_configuration
        end

        protected

        def sync_directory(dir)
          remote_base = path.empty? ? File.basename(dir) :
                                      File.join(path, File.basename(dir))
          Logger.info "Gathering remote data for '#{ remote_base }'..."
          remote_files = get_remote_files(remote_base)
          Logger.info("Gathering local data for '#{ File.expand_path(dir) }'...")
          local_files = LocalFile.find(dir, excludes)
          relative_paths = remote_files.keys.map{|p| p.downcase.sub("/#{remote_base.downcase}/", '')}.inject(local_files.keys) { |a, k|
            a << k unless a.map(&:downcase).include?(k.downcase)
            a
          }.sort_by { |a| a.downcase }
          if relative_paths.empty?
            Logger.info 'No local or remote files found'
          else
            Logger.info 'Syncing...'
            cache_files = []
            sync_block = Proc.new do |relative_path|
              local_file  = local_files[relative_path]
              remote_rev  = remote_files[relative_path.downcase]
              remote_path = File.join(remote_base, relative_path)
              metadata_cache = cloud_io.fetch_metadata_cache(remote_path)
              cache_files << metadata_cache['cache_file']
              sync_file(local_file, remote_path, remote_rev, metadata_cache)
            end

            # Execute the block sequentially or in parallel
            if thread_count > 0
              sync_in_threads(relative_paths, sync_block)
            else
              relative_paths.each(&sync_block)
            end

            # Cleanup obsolete cache files
            cloud_io.cleanup_cache(cache_files)

          end
        end

        # If an exception is raised in multiple threads, only the exception
        # raised in the first thread that Thread#join is called on will be
        # handled. So all exceptions are logged first with their details,
        # then a generic exception is raised.
        def sync_file(local_file, remote_path, remote_rev, metadata_cache)
          if local_file && File.exist?(local_file.path)
            if metadata_cache && metadata_cache['rev'] == remote_rev && local_file.md5 == metadata_cache['md5']
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
          elsif remote_rev
            @orphans << remote_path
          end
        end

        private

        def cloud_io
          @cloud_io ||= CloudIO::Dropbox.new(
            :api_key       => api_key,
            :api_secret    => api_secret,
            :cache_path    => cache_path,
            :access_type   => access_type,
            :max_retries   => max_retries,
            :retry_waitsec => retry_waitsec,
            # Syncer can not use multipart upload.
            :chunk_size    => chunk_size
          )
        end

        def get_remote_files(remote_base)
          hash = {}
          cloud_io.objects(remote_base).each do |object|
            relative_path = object.path.downcase.sub("/#{remote_base.downcase}/", '')
            hash[relative_path] = object.rev
          end
          hash
        end

        def check_configuration
          # Add Dropbox default excludes
          excludes.concat %w( **/.DS_Store )
        end
      end
    end
  end

end
