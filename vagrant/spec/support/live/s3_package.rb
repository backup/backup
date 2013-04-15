# encoding: utf-8

module BackupSpec
  class S3Package

    # Package file names sent to the remote
    attr_reader :files_sent

    def initialize(model)
      @package = model.package
      @storage = model.storages.
          select {|s| s.class == Backup::Storage::S3 }.first
      @remote_path = @storage.send(:remote_path_for, @package)
      # see Storage::Base#files_to_transfer_for
      @files_sent = @package.filenames.map {|name| name[20..-1] }.sort
    end

    # Find all the file names on the remote in remote_path
    # that include the trigger in their name.
    #
    # If files were sent successfully, this will match #files_sent.
    # If the files do not exist, or were removed by cycling, this will return [].
    def files_on_remote
      resp = @storage.send(:connection).
          get_bucket(@storage.bucket, prefix: @remote_path)
      resp.body['Contents'].map {|entry| File.basename(entry['Key']) }.sort
    end

    # This will delete the <path>/<trigger> folder.
    # e.g. <bucket>/backup_testing/my_backup/
    #
    # This will remove any package files from the remote uploaded for this
    # package or any previous package with the same trigger.
    # This way, if a test fails and this doesn't get run,
    # the next successful test will clean up everything.
    def clean_remote!
      resp = @storage.send(:connection).
          get_bucket(@storage.bucket, prefix: File.dirname(@remote_path))
      keys = resp.body['Contents'].map {|entry| entry['Key'] }

      @storage.send(:connection).
          delete_multiple_objects(@storage.bucket, keys) unless keys.empty?
    end

  end
end
