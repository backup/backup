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

  before { clean_remote }
  after  { clean_remote }

  # Each archive is 1.09 MB (1,090,000).
  # This will create 2 package files (6,291,456 + 248,544).
  # The default/minimum chunk_size for multipart upload is 5 MiB.
  # The first package file will use multipart, the second won't.

  it 'stores package', :live do
    create_model :my_backup, %q{
      Backup::Model.new(:my_backup, 'a description') do
        split_into_chunks_of 6 # MiB

        6.times do |n|
          archive "archive_#{ n }" do |archive|
            archive.add '~/test_data'
          end
        end

        config = BackupSpec::LIVE['storage']['s3']
        store_with S3 do |s3|
          s3.access_key_id      = config['access_key_id']
          s3.secret_access_key  = config['secret_access_key']
          s3.region             = config['region']
          s3.bucket             = config['bucket']
          s3.path               = config['path']
          s3.max_retries        = 3
          s3.retry_waitsec      = 5
        end
      end
    }

    job = backup_perform :my_backup

    files_sent = files_sent_for(job)
    expect( files_sent.count ).to be(2)

    objects_on_remote = objects_on_remote_for(job)
    expect( objects_on_remote.map(&:key) ).to eq files_sent

    expect(
      objects_on_remote.all? {|obj| obj.storage_class == 'STANDARD' }
    ).to be(true)

    expect(
      objects_on_remote.all? {|obj| obj.encryption.nil? }
    ).to be(true)
  end

  it 'uses server-side encryption and reduced redundancy', :live do
    create_model :my_backup, %q{
      Backup::Model.new(:my_backup, 'a description') do
        split_into_chunks_of 6 # MiB

        6.times do |n|
          archive "archive_#{ n }" do |archive|
            archive.add '~/test_data'
          end
        end

        config = BackupSpec::LIVE['storage']['s3']
        store_with S3 do |s3|
          s3.access_key_id      = config['access_key_id']
          s3.secret_access_key  = config['secret_access_key']
          s3.region             = config['region']
          s3.bucket             = config['bucket']
          s3.path               = config['path']
          s3.max_retries        = 3
          s3.retry_waitsec      = 5
          s3.encryption = :aes256
          s3.storage_class = :reduced_redundancy
        end
      end
    }

    job = backup_perform :my_backup

    files_sent = files_sent_for(job)
    expect( files_sent.count ).to be(2)

    objects_on_remote = objects_on_remote_for(job)
    expect( objects_on_remote.map(&:key) ).to eq files_sent

    expect(
      objects_on_remote.all? {|obj| obj.storage_class == 'REDUCED_REDUNDANCY' }
    ).to be(true)

    expect(
      objects_on_remote.all? {|obj| obj.encryption == 'AES256' }
    ).to be(true)
  end

  it 'cycles stored packages', :live do
    create_model :my_backup, %q{
      Backup::Model.new(:my_backup, 'a description') do
        split_into_chunks_of 6 # MiB

        6.times do |n|
          archive "archive_#{ n }" do |archive|
            archive.add '~/test_data'
          end
        end

        config = BackupSpec::LIVE['storage']['s3']
        store_with S3 do |s3|
          s3.access_key_id      = config['access_key_id']
          s3.secret_access_key  = config['secret_access_key']
          s3.region             = config['region']
          s3.bucket             = config['bucket']
          s3.path               = config['path']
          s3.max_retries        = 3
          s3.retry_waitsec      = 5
          s3.keep = 2
        end
      end
    }

    job_a = backup_perform :my_backup
    job_b = backup_perform :my_backup

    # package files for job_a should be on the remote
    files_sent = files_sent_for(job_a)
    expect( files_sent.count ).to be(2)
    expect( objects_on_remote_for(job_a).map(&:key) ).to eq files_sent

    # package files for job_b should be on the remote
    files_sent = files_sent_for(job_b)
    expect( files_sent.count ).to be(2)
    expect( objects_on_remote_for(job_b).map(&:key) ).to eq files_sent

    job_c = backup_perform :my_backup

    # package files for job_b should still be on the remote
    files_sent = files_sent_for(job_b)
    expect( files_sent.count ).to be(2)
    expect( objects_on_remote_for(job_b).map(&:key) ).to eq files_sent

    # package files for job_c should be on the remote
    files_sent = files_sent_for(job_c)
    expect( files_sent.count ).to be(2)
    expect( objects_on_remote_for(job_c).map(&:key) ).to eq files_sent

    # package files for job_a should be gone
    expect( objects_on_remote_for(job_a) ).to be_empty
  end

  private

  def cloud_io
    config = BackupSpec::LIVE['storage']['s3']
    @cloud_io ||= CloudIO::S3.new(
      :access_key_id      => config['access_key_id'],
      :secret_access_key  => config['secret_access_key'],
      :region             => config['region'],
      :bucket             => config['bucket'],
      :path               => config['path'],
      :chunk_size         => 0,
      :max_retries        => 3,
      :retry_waitsec      => 5
    )
  end

  def files_sent_for(job)
    job.model.package.filenames.map {|name|
      File.join(remote_path_for(job), name)
    }.sort
  end

  def remote_path_for(job)
    path = BackupSpec::LIVE['storage']['s3']['path']
    package = job.model.package
    File.join(path, package.trigger, package.time)
  end

  # objects_on_remote_for(job).map(&:key) should match #files_sent_for(job).
  # If the files do not exist, or were removed by cycling, this will return [].
  def objects_on_remote_for(job)
    cloud_io.objects(remote_path_for(job)).sort_by(&:key)
  end

  def clean_remote
    path = BackupSpec::LIVE['storage']['s3']['path']
    objects = cloud_io.objects(path)
    cloud_io.delete(objects) unless objects.empty?
  end

end
end
