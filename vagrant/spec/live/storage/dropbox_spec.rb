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

  # Each archive is 1.09 MB (1,090,000).
  # With a chunk_size of 1 MiB this will perform 3 PUT requests.
  it 'stores package file', :live do
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        archive :archive_a do |archive|
          archive.add '~/test_data'
        end
        archive :archive_b do |archive|
          archive.add '~/test_data'
        end

        store_with Dropbox do |db|
          db.api_key     = BackupSpec::LIVE['storage']['dropbox']['api_key']
          db.api_secret  = BackupSpec::LIVE['storage']['dropbox']['api_secret']
          db.access_type = BackupSpec::LIVE['storage']['dropbox']['access_type']
          db.path        = BackupSpec::LIVE['storage']['dropbox']['path']
          db.chunk_size  = 1
        end
      end
    EOS

    job = backup_perform :my_backup, '--cache-path=/vagrant/spec/live/.cache'
    package = BackupSpec::DropboxPackage.new(job.model)

    expect( package.files_sent.count ).to be(1)
    expect( package.files_on_remote ).to eq package.files_sent

    package.clean_remote!
  end

  # With Splitter set a 1 MiB, this will create 3 package files.
  it 'stores multiple package files', :live do
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        split_into_chunks_of 1

        archive :archive_a do |archive|
          archive.add '~/test_data'
        end
        archive :archive_b do |archive|
          archive.add '~/test_data'
        end

        store_with Dropbox do |db|
          db.api_key     = BackupSpec::LIVE['storage']['dropbox']['api_key']
          db.api_secret  = BackupSpec::LIVE['storage']['dropbox']['api_secret']
          db.access_type = BackupSpec::LIVE['storage']['dropbox']['access_type']
          db.path        = BackupSpec::LIVE['storage']['dropbox']['path']
        end
      end
    EOS

    job = backup_perform :my_backup, '--cache-path=/vagrant/spec/live/.cache'
    package = BackupSpec::DropboxPackage.new(job.model)

    expect( package.files_sent.count ).to be(3)
    expect( package.files_on_remote ).to eq package.files_sent

    package.clean_remote!
  end

  it 'cycles stored packages', :live do
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        archive :archive_a do |archive|
          archive.add '~/test_data/dir_a/file_a'
        end

        store_with Dropbox do |db|
          db.api_key     = BackupSpec::LIVE['storage']['dropbox']['api_key']
          db.api_secret  = BackupSpec::LIVE['storage']['dropbox']['api_secret']
          db.access_type = BackupSpec::LIVE['storage']['dropbox']['access_type']
          db.path        = BackupSpec::LIVE['storage']['dropbox']['path']
          db.keep = 2
        end
      end
    EOS

    job = backup_perform :my_backup, '--cache-path=/vagrant/spec/live/.cache'
    package_a = BackupSpec::DropboxPackage.new(job.model)

    job = backup_perform :my_backup, '--cache-path=/vagrant/spec/live/.cache'
    package_b = BackupSpec::DropboxPackage.new(job.model)

    # a and b should be on the remote
    expect( package_a.files_sent.count ).to be(1)
    expect( package_a.files_on_remote ).to eq package_a.files_sent
    expect( package_b.files_sent.count ).to be(1)
    expect( package_b.files_on_remote ).to eq package_b.files_sent

    job = backup_perform :my_backup, '--cache-path=/vagrant/spec/live/.cache'
    package_c = BackupSpec::DropboxPackage.new(job.model)

    # b and c should be on the remote
    expect( package_b.files_sent.count ).to be(1)
    expect( package_b.files_on_remote ).to eq package_b.files_sent
    expect( package_c.files_sent.count ).to be(1)
    expect( package_c.files_on_remote ).to eq package_c.files_sent

    # a should be gone
    expect( package_a.files_on_remote ).to be_empty

    package_c.clean_remote!
  end
end
end
