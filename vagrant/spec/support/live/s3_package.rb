# encoding: utf-8

module BackupSpec
  class S3Package

    # Package file names sent to the remote
    attr_reader :files_sent

    def initialize(model)
      @package = model.package
      @storage = model.storages.
          select {|s| s.class == Backup::Storage::S3 }.first
      @connection = @storage.send(:connection)
      @remote_path = @storage.send(:remote_path)
      @files_sent = @package.filenames.sort
    end

    # Find all the file names on the remote in remote_path.
    #
    # If files were sent successfully, this will match #files_sent.
    # If the files do not exist, or were removed by cycling, this will return [].
    def files_on_remote
      @bucket_contents = nil
      bucket_contents.map {|item| File.basename(item['Key']) }.sort
    end

    # This will delete the <path>/<trigger> folder.
    # e.g. <bucket>/backup_testing/my_backup/
    #
    # This will remove any package files from the remote uploaded for this
    # package or any previous package with the same trigger.
    # This way, if a test fails and this doesn't get run,
    # the next successful test will clean up everything.
    def clean_remote!
      resp = @connection.get_bucket(
        @storage.bucket, prefix: File.dirname(@remote_path)
      )
      keys = resp.body['Contents'].map {|item| item['Key'] }

      @connection.delete_multiple_objects(@storage.bucket, keys) unless keys.empty?
    end

    def stored_with_reduced_redundancy?
      bucket_contents.all? {|item|
        item['StorageClass'] == 'REDUCED_REDUNDANCY'
      }
    end

    def stored_with_encryption?(algorithm = 'AES256')
      bucket_contents.all? {|item|
        @connection.head_object(@storage.bucket, item['Key']).
            headers['x-amz-server-side-encryption'] == algorithm
      }
    end

    private

    def bucket_contents
      @bucket_contents ||= begin
        resp = @connection.get_bucket(@storage.bucket, prefix: @remote_path)
        resp.body['Contents']
      end
    end
  end
end
