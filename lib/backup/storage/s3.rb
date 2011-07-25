# encoding: utf-8

##
# Only load the Fog gem when the Backup::Storage::S3 class is loaded
Backup::Dependency.load('fog')

module Backup
  module Storage
    class S3 < Base

      ##
      # Amazon Simple Storage Service (S3) Credentials
      attr_accessor :access_key_id, :secret_access_key

      ##
      # Amazon S3 bucket name and path
      attr_accessor :bucket, :path

      ##
      # Region of the specified S3 bucket
      attr_accessor :region

      ##
      # Creates a new instance of the Amazon S3 storage object
      # First it sets the defaults (if any exist) and then evaluates
      # the configuration block which may overwrite these defaults
      #
      # Currently available regions:
      #   eu-west-1, us-east-1, ap-southeast-1, us-west-1
      def initialize(&block)
        load_defaults!

        @path ||= 'backups'

        instance_eval(&block) if block_given?

        @time = TIME
      end

      ##
      # This is the remote path to where the backup files will be stored
      def remote_path
        File.join(path, TRIGGER).sub(/^\//, '')
      end

      ##
      # This is the provider that Fog uses for the S3 Storage
      def provider
        'AWS'
      end

      ##
      # Performs the backup transfer
      def perform!
        transfer!
        cycle!
      end

    private

      ##
      # Establishes a connection to Amazon S3 and returns the Fog object.
      # Not doing any instance variable caching because this object gets persisted in YAML
      # format to a file and will issues. This, however has no impact on performance since it only
      # gets invoked once per object for a #transfer! and once for a remove! Backups run in the
      # background anyway so even if it were a bit slower it shouldn't matter.
      def connection
        Fog::Storage.new(
          :provider               => provider,
          :aws_access_key_id      => access_key_id,
          :aws_secret_access_key  => secret_access_key,
          :region                 => region
        )
      end

      ##
      # Transfers the archived file to the specified Amazon S3 bucket
      def transfer!
        # maximum file size 5GB
        max_file_size = 5368709120
        # split size must be between 5MB and 5GB
        max_split_size = max_file_size - 5242880

        begin
          local_file_path = File.join(local_path, local_file)

          Logger.message("#{ self.class } started transferring \"#{ remote_file }\".")
          connection.sync_clock
          if File.stat(local_file_path).size <= max_file_size
            connection.put_object(
              bucket,
              File.join(remote_path, remote_file),
              File.open(File.join(local_path, local_file))
            )
          else
            Logger.message("#{ self.class } started multipart uploading \"#{ remote_file }\".")

            workspace_path = local_path + "/workspace"
            create_workspace(workspace_path)

            `split -b #{max_split_size}  #{local_file_path} #{workspace_path}/#{local_file}.0`

            upload_id = initiate_multipart_upload
            etags = upload_part(workspace_path, upload_id)

            s3_md5 = complete_multipart_upload(etags, upload_id)
            ## please check etag
            # if it's differrent from local_file, try to upload again.
            # ex)
            # require 'digest/md5'
            # original_md5 = Digest::MD5.hexdigest(File.open(local_file_path).read)

            remove_workspace(workspace_path)
          end
        rescue Excon::Errors::NotFound => e
          raise "An error occurred while trying to transfer the backup, please make sure the bucket exists.\n #{e.inspect}"
        end
      end

      def initiate_multipart_upload
        res = connection.initiate_multipart_upload(
          bucket,
          File.join(remote_path, remote_file)
        )
        res.body['UploadId']
      end

      def upload_part workspace_path, upload_id
        etags = []
        split_files = Dir.entries(workspace_path).select{|file| file != ".." and file != "."}.sort

        split_files.each_with_index do |split_file, index|
          Logger.message("uploading #{index + 1} / #{split_files.size}")
          res = connection.upload_part(
            bucket,
            File.join(remote_path, remote_file),
            upload_id,
            index + 1,
            File.open(File.join(workspace_path, split_file))
          )
          etags << res.headers['ETag']
        end
        etags
      end

      def complete_multipart_upload etags, upload_id
        res = connection.complete_multipart_upload(
          bucket,
          File.join(remote_path, remote_file),
          upload_id,
          etags
        )
        res.body['ETag']
      end

      def create_workspace workspace_path
        Dir.mkdir(workspace_path)
      end

      def remove_workspace workspace_path
        split_files = Dir.entries(workspace_path).select{|file| file != ".." and file != "."}.sort
        split_files.each do |split_file|
          File.delete(File.join(workspace_path, split_file))
        end
        Dir.rmdir(workspace_path)
      end

      ##
      # Removes the transferred archive file from the Amazon S3 bucket
      def remove!
        begin
          connection.sync_clock
          connection.delete_object(bucket, File.join(remote_path, remote_file))
        rescue Excon::Errors::SocketError; end
      end

    end
  end
end
