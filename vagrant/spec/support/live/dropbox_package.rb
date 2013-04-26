# encoding: utf-8

module BackupSpec
  class DropboxPackage

    # Package file names sent to the remote
    attr_reader :files_sent

    def initialize(model)
      @package = model.package
      @storage = model.storages.
          select {|s| s.class == Backup::Storage::Dropbox }.first
      @remote_path = @storage.send(:remote_path)
      @files_sent = @package.filenames.sort
    end

    # Find all the file names on the remote in remote_path
    # that include the trigger in their name.
    #
    # If files were sent successfully, this will match #files_sent.
    # If the files do not exist, or were removed by cycling, this will return [].
    def files_on_remote
      metadata = @storage.send(:connection).search(@remote_path, @package.trigger)
      metadata.map {|entry| File.basename(entry['path']) }.sort
    end

    # This will delete the <path>/<trigger> folder.
    # e.g. <dropbox_root>/<app_folder>/backup_testing/my_backup/
    #
    # This will remove any package files from the remote uploaded for this
    # package or any previous package with the same trigger.
    # This way, if a test fails and this doesn't get run,
    # the next successful test will clean up everything.
    def clean_remote!
      @storage.send(:connection).file_delete(File.dirname(@remote_path))
    end

  end
end
