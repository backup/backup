# encoding: utf-8

require File.expand_path('../../../spec_helper', __FILE__)

# To run these tests, you need to setup your Dropbox credentials in
#   /vagrant/spec/live.yml
# You also need to have a cached authorization file in
#   /vagrant/spec/live/.cache/
# If you already have one, you can simply copy it there.
# If not, change a test from :live to :focus and run it to generate one.
module Backup
describe Storage::Dropbox,
    :if => BackupSpec::LIVE['storage']['dropbox']['specs_enabled'] == true do

  # Note that the remote will only be cleaned after successful tests,
  # but it will clean files uploaded by all previous failed tests.

  before do
    # Each archive is 1.09 MB (1,090,000).
    # With Splitter set to 2 MiB, package files will be 2,097,152 and 1,172,848.
    # With #chunk_size set to 1, the chunked uploader will upload 1 MiB per request.
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        split_into_chunks_of 2 # MiB

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
          db.api_key     = config['api_key']
          db.api_secret  = config['api_secret']
          db.access_type = config['access_type']
          db.path        = config['path']
          db.chunk_size  = 1 # MiB
          db.keep = 2
        end
      end
    EOS
  end

  it 'stores package files', :live do
    job = backup_perform :my_backup, '--cache-path=/vagrant/spec/live/.cache'

    files_sent = files_sent_for(job)
    expect( files_sent.count ).to be(2)
    expect( files_on_remote_for(job) ).to eq files_sent

    clean_remote(job)
  end

  it 'cycles stored packages', :live do
    job_a = backup_perform :my_backup, '--cache-path=/vagrant/spec/live/.cache'
    job_b = backup_perform :my_backup, '--cache-path=/vagrant/spec/live/.cache'

    # package files for job_a should be on the remote
    files_sent = files_sent_for(job_a)
    expect( files_sent.count ).to be(2)
    expect( files_on_remote_for(job_a) ).to eq files_sent

    # package files for job_b should be on the remote
    files_sent = files_sent_for(job_b)
    expect( files_sent.count ).to be(2)
    expect( files_on_remote_for(job_b) ).to eq files_sent

    job_c = backup_perform :my_backup, '--cache-path=/vagrant/spec/live/.cache'

    # package files for job_b should still be on the remote
    files_sent = files_sent_for(job_b)
    expect( files_sent.count ).to be(2)
    expect( files_on_remote_for(job_b) ).to eq files_sent

    # package files for job_c should be on the remote
    files_sent = files_sent_for(job_c)
    expect( files_sent.count ).to be(2)
    expect( files_on_remote_for(job_c) ).to eq files_sent

    # package files for job_a should be gone
    expect( files_on_remote_for(job_a) ).to be_empty

    clean_remote(job_a) # will clean up after all jobs
  end

  private

  def files_sent_for(job)
    job.model.package.filenames.map {|name|
      File.join('/', remote_path_for(job), name)
    }.sort
  end

  def remote_path_for(job)
    path = BackupSpec::LIVE['storage']['dropbox']['path']
    package = job.model.package
    File.join(path, package.trigger, package.time)
  end

  # files_on_remote_for(job) should match #files_sent_for(job).
  # If the files do not exist, or were removed by cycling, this will return [].
  def files_on_remote_for(job)
    storage = job.model.storages.first
    # search(dir_to_search, query) => metadata for each entry
    # entry['path'] will start with '/'
    storage.send(:connection).search(remote_path_for(job), job.model.trigger).
        map {|entry| entry['path'] }.sort
  end

  def clean_remote(job)
    storage = job.model.storages.first
    path = BackupSpec::LIVE['storage']['dropbox']['path']
    storage.send(:connection).file_delete(path)
  end
end
end
