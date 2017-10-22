require File.expand_path("../../../spec_helper", __FILE__)

module Backup
  describe Storage::Dropbox do
    # Note that the remote will only be cleaned after successful tests,
    # but it will clean files uploaded by all previous failed tests.

    before do
      create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do

        archive :archive_a do |archive|
          archive.add '~/test_data'
        end
        archive :archive_b do |archive|
          archive.add '~/test_data'
        end
        archive :archive_c do |archive|
          archive.add '~/test_data'
        end

        config = BackupSpec::LIVE['storage']['dropbox']
        store_with Dropbox do |db|
          db.api_token   = config['api_token']
          db.path        = config['path']
          db.chunk_size  = 1 # MiB
          db.keep = 2
        end
      end
      EOS
    end

    it "stores package files", :live do
      job = backup_perform :my_backup

      files_sent = files_sent_for(job)
      expect(files_sent.count).to be(1)
      expect(files_on_remote_for(job)).to eq files_sent

      clean_remote(job)
    end

    it "cycles stored packages", :live do
      job_a = backup_perform :my_backup
      job_b = backup_perform :my_backup

      # package files for job_a should be on the remote
      files_sent = files_sent_for(job_a)
      expect(files_sent.count).to be(1)
      expect(files_on_remote_for(job_a)).to eq files_sent

      # package files for job_b should be on the remote
      files_sent = files_sent_for(job_b)
      expect(files_sent.count).to be(1)
      expect(files_on_remote_for(job_b)).to eq files_sent

      job_c = backup_perform :my_backup

      # package files for job_b should still be on the remote
      files_sent = files_sent_for(job_b)
      expect(files_sent.count).to be(1)
      expect(files_on_remote_for(job_b)).to eq files_sent

      # package files for job_c should be on the remote
      files_sent = files_sent_for(job_c)
      expect(files_sent.count).to be(1)
      expect(files_on_remote_for(job_c)).to eq files_sent

      # package files for job_a should be gone
      expect(files_on_remote_for(job_a)).to be_empty

      clean_remote(job_a) # will clean up after all jobs
    end

    private

    def files_sent_for(job)
      job.model.package.filenames.map do |name|
        File.join("/", remote_path_for(job), name)
      end.sort
    end

    def remote_path_for(job)
      path = BackupSpec::LIVE["storage"]["dropbox"]["path"]
      package = job.model.package
      File.join("/", path, package.trigger, package.time)
    end

    # files_on_remote_for(job) should match #files_sent_for(job).
    # If the files do not exist, or were removed by cycling, this will return [].
    def files_on_remote_for(job)
      storage = job.model.storages.first
      begin
        storage.send(:client).list_folder(remote_path_for(job)).entries.map(&:path_display).sort
      rescue DropboxApi::Errors::NotFoundError
        []
      end
    end

    def clean_remote(job)
      storage = job.model.storages.first
      path = File.join("/", BackupSpec::LIVE["storage"]["dropbox"]["path"])
      storage.send(:client).delete(path)
    end
  end
end
