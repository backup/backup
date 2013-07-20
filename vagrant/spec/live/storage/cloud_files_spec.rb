# encoding: utf-8

require File.expand_path('../../../spec_helper', __FILE__)

# To run these tests, you need to setup your Cloudfiles credentials in
#   /vagrant/spec/live.yml
#
# It's recommended you use a dedicated Container for this, like:
#   backup.testing.container
#
module Backup
describe Storage::CloudFiles,
    :if => BackupSpec::LIVE['storage']['cloudfiles']['specs_enabled'] == true do

  it 'stores package file', :live do
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        archive :archive_a do |archive|
          archive.add '~/test_data/dir_a/file_a'
        end

        store_with CloudFiles do |cf|
          cf.username   = BackupSpec::LIVE['storage']['cloudfiles']['username']
          cf.api_key    = BackupSpec::LIVE['storage']['cloudfiles']['api_key']
          cf.auth_url   = BackupSpec::LIVE['storage']['cloudfiles']['auth_url']
          cf.servicenet = BackupSpec::LIVE['storage']['cloudfiles']['servicenet']
          cf.container  = BackupSpec::LIVE['storage']['cloudfiles']['container']
          cf.path       = BackupSpec::LIVE['storage']['cloudfiles']['path']
        end
      end
    EOS

    job = backup_perform :my_backup
    package = BackupSpec::CloudFilesPackage.new(job.model)

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

        store_with CloudFiles do |cf|
          cf.username   = BackupSpec::LIVE['storage']['cloudfiles']['username']
          cf.api_key    = BackupSpec::LIVE['storage']['cloudfiles']['api_key']
          cf.auth_url   = BackupSpec::LIVE['storage']['cloudfiles']['auth_url']
          cf.servicenet = BackupSpec::LIVE['storage']['cloudfiles']['servicenet']
          cf.container  = BackupSpec::LIVE['storage']['cloudfiles']['container']
          cf.path       = BackupSpec::LIVE['storage']['cloudfiles']['path']
        end
      end
    EOS

    job = backup_perform :my_backup
    package = BackupSpec::CloudFilesPackage.new(job.model)

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

        store_with CloudFiles do |cf|
          cf.username   = BackupSpec::LIVE['storage']['cloudfiles']['username']
          cf.api_key    = BackupSpec::LIVE['storage']['cloudfiles']['api_key']
          cf.auth_url   = BackupSpec::LIVE['storage']['cloudfiles']['auth_url']
          cf.servicenet = BackupSpec::LIVE['storage']['cloudfiles']['servicenet']
          cf.container  = BackupSpec::LIVE['storage']['cloudfiles']['container']
          cf.path       = BackupSpec::LIVE['storage']['cloudfiles']['path']
          cf.keep = 2
        end
      end
    EOS

    job = backup_perform :my_backup
    package_a = BackupSpec::CloudFilesPackage.new(job.model)

    job = backup_perform :my_backup
    package_b = BackupSpec::CloudFilesPackage.new(job.model)

    # a and b should be on the remote
    expect( package_a.files_sent.count ).to be(1)
    expect( package_a.files_on_remote ).to eq package_a.files_sent
    expect( package_b.files_sent.count ).to be(1)
    expect( package_b.files_on_remote ).to eq package_b.files_sent

    job = backup_perform :my_backup
    package_c = BackupSpec::CloudFilesPackage.new(job.model)

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
