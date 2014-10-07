# encoding: utf-8
require 'backup/cloud_io/base'
require 'dropbox_sdk'
require 'fileutils'
require 'digest/sha1'
require 'yaml'

module Backup
  module CloudIO
    class Dropbox < Base
      class Error < Backup::Error; end

      MUTEX = Mutex.new
      MAX_FILE_SIZE = 1024**3 * 5 # 5 GiB
      MAX_MULTIPART_SIZE = 1024**4 * 5 # 5 TiB

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

      def initialize(options = {})
        super

        @api_key = options[:api_key]
        @api_secret = options[:api_secret]
        @cache_path = options[:cache_path]
        @access_type = options[:access_type]
        @chunk_size = options[:chunk_size]
      end

      # The Syncer may call this method in multiple threads.
      # However, #objects is always called prior to multithreading.
      def upload(src, dest)
        result=nil
        File.open(src, 'r') do |file|
          # Only do chunked uploads for large enough files
          # This is to prevent an error on zero byte files plus it made sense
          if file.stat.size > (1024**2 * chunk_size)
            uploader = connection.get_chunked_uploader(file, file.stat.size)
            while uploader.offset < uploader.total_size
              with_retries("Chunk UPLOAD #{src} to #{dest}") do
                uploader.upload(1024**2 * chunk_size)
              end
            end
            with_retries("Finish UPLOAD #{src} to #{dest}") do
              result = uploader.finish(dest, true)
            end
          else
            with_retries("UPLOAD #{src} to #{dest}") do
              result = connection.put_file(dest, file, true, nil)
            end
          end
        end
        result
      end

      # Returns all objects in the Dropbox folder with the given path prefix.
      #
      # - #get_bucket returns a max of 1000 objects per request.
      # - Returns objects in alphabetical order.
      # - If marker is given, only objects after the marker are in the response.
      def objects(prefix)
        objects = []
        prefix = prefix.gsub(/^\/?(.+?)\/?$/, '/\1')
        result = cursor = nil
        while result.nil? || result['has_more']
          result = connection.delta(cursor, prefix)
          cursor = result['cursor']
          result['entries'].reject{|e| e[1]['is_dir'] || e[1]['is_deleted'] }.each do |entry|
            objects << Object.new(self, *entry)
          end
        end
        objects
      rescue => err
        # Folder doesn't exist or there was a problem loading, raise an error
        raise Error.wrap(err, "Could not load objects from folder #{prefix}")
      end

      # Delete specified object(s) from Dropbox.
      #
      # - Called by the Storage (with objects) and the Syncer (with keys)
      # - Deletes objects one at a time.
      # - Missing objects will be ignored.
      def delete(objects_or_keys)
        keys = Array(objects_or_keys).dup
        keys.map!(&:path) if keys.first.is_a?(Object)
        with_retries('DELETE Multiple Objects') do
          keys.each do |path|
            connection.file_delete(path)
          end
        end
      end

      ##
      # Serializes and writes the Dropbox file metadata to a local cache file
      def cache_file_metadata!(metadata)
        cache_file = metadata_cache_file(metadata['path'])
        File.open(cache_file, "w") do |f|
          f.write(metadata.to_yaml)
        end
      end

      ##
      # Fetches the specified file's cached metadata from a local cache file
      def fetch_file_metadata(path)
        cache_file = metadata_cache_file(path)
        metadata = YAML.load_file(cache_file) if File.exist?(cache_file)
        (metadata || {}).merge('cache_file' => cache_file)
      end

      def cleanup_cache(cache_files)
        Dir[File.join(account_cache_directory, 'metadata', '*')].each do |f|
          if File.file?(f) && !cache_files.include?(f)
            Logger.info "Deleting obsolete cache file #{f}..."
            File.delete(f)
          end
        end
      end

      private

      ##
      # The initial connection to Dropbox will provide the user with an
      # authorization url. The user must open this URL and confirm that the
      # authorization successfully took place. If this is the case, then the
      # user hits 'enter' and the session will be properly established.
      # Immediately after establishing the session, the session will be
      # serialized and written to a cache file in +cache_path+.
      # The cached file will be used from that point on to re-establish a
      # connection with Dropbox at a later time. This allows the user to avoid
      # having to go to a new Dropbox URL to authorize over and over again.
      def connection
        return @connection if @connection

        unless session = cached_session
          Logger.info "Creating a new session!"
          session = create_write_and_return_new_session!
        end

        # will raise an error if session not authorized
        @connection = DropboxClient.new(session, access_type)

      rescue => err
        raise Error.wrap(err, 'Authorization Failed')
      end

      ##
      # Attempt to load a cached session
      def cached_session
        session = false
        if File.exist?(session_cache_file)
          begin
            session = DropboxSession.deserialize(File.read(session_cache_file))
            Logger.info "Session data loaded from cache!"

          rescue => err
            Logger.warn Error.wrap(err, <<-EOS)
              Could not read session data from cache.
              Cache data might be corrupt.
            EOS
          end
        end
        session
      end

      def account_cache_directory
        File.join(cache_path.start_with?('/') ? cache_path : File.join(Config.root_path, cache_path), api_key + api_secret)
      end

      def session_cache_file
        cache_file = File.join(account_cache_directory, 'session')
        # Check for an older session file and move it to the new location
        if File.exist?(account_cache_directory) && File.file?(account_cache_directory)
          FileUtils.mv(account_cache_directory, "#{account_cache_directory}.tmp")
          FileUtils.mkdir_p(account_cache_directory)
          FileUtils.mv("#{account_cache_directory}.tmp", cache_file)
        end
        FileUtils.mkdir_p(File.dirname(cache_file))
        cache_file
      end

      def metadata_cache_file(path)
        file_key=path.gsub(/^\/?/, '').downcase
        cache_key=Digest::SHA1.hexdigest(file_key)
        cache_file=File.join(account_cache_directory, 'metadata', cache_key)
        FileUtils.mkdir_p(File.dirname(cache_file))
        cache_file
      end

      ##
      # Serializes and writes the Dropbox session to a cache file
      def cache_session!(session)
        File.open(session_cache_file, "w") do |cache_file|
          cache_file.write(session.serialize)
        end
      end

      ##
      # Create a new session, write a serialized version of it to the
      # .cache directory, and return the session object
      def create_write_and_return_new_session!
        require 'timeout'

        session = DropboxSession.new(api_key, api_secret)

        # grab the request token for session
        session.get_request_token

        template = Backup::Template.new(
          {:session => session, :session_cache_file => session_cache_file}
        )
        template.render("storage/dropbox/authorization_url.erb")

        # wait for user to hit 'return' to continue
        Timeout::timeout(180) { STDIN.gets }

        # this will raise an error if the user did not
        # visit the authorization_url and grant access
        #
        # get the access token from the server
        # this will be stored with the session in the cache file
        session.get_access_token

        template.render("storage/dropbox/authorized.erb")
        cache_session!(session)
        template.render("storage/dropbox/cache_file_written.erb")

        session

      rescue => err
        raise Error.wrap(err, 'Could not create or authenticate a new session')
      end

      class Object
        attr_reader :key, :rev, :path, :is_dir, :client_mtime, :bytes, :modified

        def initialize(cloud_io, key, metadata)
          @cloud_io = cloud_io
          @key = key
          @rev = metadata['rev']
          @path = metadata['path']
          @is_dir = metadata['is_dir']
          @client_mtime = metadata['client_mtime']
          @bytes = metadata['bytes']
          @modified = metadata['modified']
        end

      end

    end
  end
end
