# encoding: utf-8

require File.expand_path('../../../spec_helper', __FILE__)

# To run these tests, you need to setup your AWS S3 credentials in
#   /vagrant/spec/live.yml
#
# It's recommended you use a dedicated Bucket for this, like:
#   <aws_username>.backup.testing
#
# Note: The S3 Bucket you use should have read-after-write consistency.
#       So don't use the US Standard region.
module Backup
describe Storage::S3,
    :if => BackupSpec::LIVE['storage']['s3']['specs_enabled'] == true do

  it 'stores package file', :live do
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        archive :archive_a do |archive|
          archive.add '~/test_data/dir_a/file_a'
        end

        store_with S3 do |s3|
          s3.access_key_id      = BackupSpec::LIVE['storage']['s3']['access_key_id']
          s3.secret_access_key  = BackupSpec::LIVE['storage']['s3']['secret_access_key']
          s3.region             = BackupSpec::LIVE['storage']['s3']['region']
          s3.bucket             = BackupSpec::LIVE['storage']['s3']['bucket']
          s3.path               = BackupSpec::LIVE['storage']['s3']['path']
        end
      end
    EOS

    job = backup_perform :my_backup
    package = BackupSpec::S3Package.new(job.model)

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

        store_with S3 do |s3|
          s3.access_key_id      = BackupSpec::LIVE['storage']['s3']['access_key_id']
          s3.secret_access_key  = BackupSpec::LIVE['storage']['s3']['secret_access_key']
          s3.region             = BackupSpec::LIVE['storage']['s3']['region']
          s3.bucket             = BackupSpec::LIVE['storage']['s3']['bucket']
          s3.path               = BackupSpec::LIVE['storage']['s3']['path']
        end
      end
    EOS

    job = backup_perform :my_backup
    package = BackupSpec::S3Package.new(job.model)

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

        store_with S3 do |s3|
          s3.access_key_id      = BackupSpec::LIVE['storage']['s3']['access_key_id']
          s3.secret_access_key  = BackupSpec::LIVE['storage']['s3']['secret_access_key']
          s3.region             = BackupSpec::LIVE['storage']['s3']['region']
          s3.bucket             = BackupSpec::LIVE['storage']['s3']['bucket']
          s3.path               = BackupSpec::LIVE['storage']['s3']['path']
          s3.keep = 2
        end
      end
    EOS

    job = backup_perform :my_backup
    package_a = BackupSpec::S3Package.new(job.model)

    job = backup_perform :my_backup
    package_b = BackupSpec::S3Package.new(job.model)

    # a and b should be on the remote
    expect( package_a.files_sent.count ).to be(1)
    expect( package_a.files_on_remote ).to eq package_a.files_sent
    expect( package_b.files_sent.count ).to be(1)
    expect( package_b.files_on_remote ).to eq package_b.files_sent

    job = backup_perform :my_backup
    package_c = BackupSpec::S3Package.new(job.model)

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
