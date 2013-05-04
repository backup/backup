# encoding: utf-8

module BackupSpec
  class CloudFilesPackage

    # Package file names sent to the remote
    attr_reader :files_sent

    def initialize(model)
      @package = model.package
      @storage = model.storages.
          select {|s| s.class == Backup::Storage::CloudFiles }.first
      @remote_path = @storage.send(:remote_path)
      @files_sent = @package.filenames.sort
    end

    # Find all the file names on the remote in remote_path.
    #
    # If files were sent successfully, this will match #files_sent.
    # If the files do not exist, or were removed by cycling, this will return [].
    def files_on_remote
      resp = @storage.send(:connection).
          get_container(@storage.container, prefix: @remote_path)
      resp.body.map {|entry| File.basename(entry['name']) }.sort
    end

    # This will delete the <path>/<trigger> folder.
    # e.g. <container>/backup_testing/my_backup/
    #
    # This will remove any package files from the remote uploaded for this
    # package or any previous package with the same trigger.
    # This way, if a test fails and this doesn't get run,
    # the next successful test will clean up everything.
    def clean_remote!
      resp = @storage.send(:connection).
          get_container(@storage.container, prefix: File.dirname(@remote_path))
      resp.body.each do |entry|
        @storage.send(:connection).delete_object(@storage.container, entry['name'])
      end
    end
  end
end
