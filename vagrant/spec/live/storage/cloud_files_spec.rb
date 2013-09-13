# encoding: utf-8

require File.expand_path('../../../spec_helper', __FILE__)

# To run these tests, you need to setup your Cloudfiles credentials in
#   /vagrant/spec/live.yml
#
# It's recommended you use dedicated Containers for this, like:
#   backup.testing.container
#   backup.testing.segments.container
#
module Backup
describe Storage::CloudFiles,
    :if => BackupSpec::LIVE['storage']['cloudfiles']['specs_enabled'] == true do

  before { clean_remote }
  after  { clean_remote }

  # Each archive is 1.09 MB (1,090,000).
  # Each job here will create 2 package files (6,291,456 + 248,544).
  # With :segment_size at 2 MiB, the first package file will be stored
  # as a SLO with 3 segments. The second package file will use put_object.

  it 'stores package', :live do
    create_model :my_backup, %q{
      Backup::Model.new(:my_backup, 'a description') do
        split_into_chunks_of 6 # MiB

        6.times do |n|
          archive "archive_#{ n }" do |archive|
            archive.add '~/test_data'
          end
        end

        config = BackupSpec::LIVE['storage']['cloudfiles']
        store_with CloudFiles do |cf|
          cf.username           = config['username']
          cf.api_key            = config['api_key']
          cf.auth_url           = config['auth_url']
          cf.region             = config['region']
          cf.servicenet         = config['servicenet']
          cf.container          = config['container']
          cf.segments_container = config['segments_container']
          cf.path               = config['path']
          cf.max_retries        = 3
          cf.retry_waitsec      = 5
          cf.segment_size       = 2 # MiB
          cf.days_to_keep = 1
        end
      end
    }

    job = backup_perform :my_backup

    files_sent = files_sent_for(job)
    expect( files_sent.count ).to be(2)

    objects_on_remote = objects_on_remote_for(job)
    expect( objects_on_remote.map(&:name) ).to eq files_sent
    expect( objects_on_remote.all?(&:marked_for_deletion?) ).to be(true)

    segments_on_remote = segments_on_remote_for(job)
    expect( segments_on_remote.count ).to be(3)
    expect( segments_on_remote.all?(&:marked_for_deletion?) ).to be(true)
  end

  it 'cycles package', :live do
    create_model :my_backup, %q{
      Backup::Model.new(:my_backup, 'a description') do
        split_into_chunks_of 6 # MiB

        6.times do |n|
          archive "archive_#{ n }" do |archive|
            archive.add '~/test_data'
          end
        end

        config = BackupSpec::LIVE['storage']['cloudfiles']
        store_with CloudFiles do |cf|
          cf.username           = config['username']
          cf.api_key            = config['api_key']
          cf.auth_url           = config['auth_url']
          cf.region             = config['region']
          cf.servicenet         = config['servicenet']
          cf.container          = config['container']
          cf.segments_container = config['segments_container']
          cf.path               = config['path']
          cf.max_retries        = 3
          cf.retry_waitsec      = 5
          cf.segment_size       = 2 # MiB
          cf.keep = 2
        end
      end
    }

    job_a = backup_perform :my_backup
    job_b = backup_perform :my_backup

    # package files for job_a should be on the remote
    files_sent = files_sent_for(job_a)
    expect( files_sent.count ).to be(2)

    objects_on_remote = objects_on_remote_for(job_a)
    expect( objects_on_remote.map(&:name) ).to eq files_sent
    expect( objects_on_remote.any?(&:marked_for_deletion?) ).to be(false)

    segments_on_remote = segments_on_remote_for(job_a)
    expect( segments_on_remote.count ).to be(3)
    expect( segments_on_remote.any?(&:marked_for_deletion?) ).to be(false)

    # package files for job_b should be on the remote
    files_sent = files_sent_for(job_b)
    expect( files_sent.count ).to be(2)

    objects_on_remote = objects_on_remote_for(job_b)
    expect( objects_on_remote.map(&:name) ).to eq files_sent
    expect( objects_on_remote.any?(&:marked_for_deletion?) ).to be(false)

    segments_on_remote = segments_on_remote_for(job_b)
    expect( segments_on_remote.count ).to be(3)
    expect( segments_on_remote.any?(&:marked_for_deletion?) ).to be(false)

    job_c = backup_perform :my_backup

    # package files for job_b should still be on the remote
    files_sent = files_sent_for(job_b)
    expect( files_sent.count ).to be(2)
    expect( objects_on_remote_for(job_b).map(&:name) ).to eq files_sent
    expect( segments_on_remote_for(job_b).count ).to be(3)

    # package files for job_c should be on the remote
    files_sent = files_sent_for(job_c)
    expect( files_sent.count ).to be(2)

    objects_on_remote = objects_on_remote_for(job_c)
    expect( objects_on_remote.map(&:name) ).to eq files_sent
    expect( objects_on_remote.any?(&:marked_for_deletion?) ).to be(false)

    segments_on_remote = segments_on_remote_for(job_c)
    expect( segments_on_remote.count ).to be(3)
    expect( segments_on_remote.any?(&:marked_for_deletion?) ).to be(false)

    # package files for job_a should be gone
    expect( objects_on_remote_for(job_a) ).to be_empty
    expect( segments_on_remote_for(job_a) ).to be_empty
  end

  private

  def config
    config = BackupSpec::LIVE['storage']['cloudfiles']
    @config ||= {
      :username           => config['username'],
      :api_key            => config['api_key'],
      :auth_url           => config['auth_url'],
      :region             => config['region'],
      :servicenet         => config['servicenet'],
      :container          => config['container'],
      :segments_container => config['segments_container'],
      :segment_size       => 0,
      :max_retries        => 3,
      :retry_waitsec      => 5
    }
  end

  def cloud_io
    @cloud_io ||= CloudIO::CloudFiles.new(config)
  end

  def segments_cloud_io
    @segments_cloud_io ||= CloudIO::CloudFiles.new(
      config.merge(:container => config[:segments_container])
    )
  end

  def files_sent_for(job)
    job.model.package.filenames.map {|name|
      File.join(remote_path_for(job), name)
    }.sort
  end

  def remote_path_for(job)
    path = BackupSpec::LIVE['storage']['cloudfiles']['path']
    package = job.model.package
    File.join(path, package.trigger, package.time)
  end

  # objects_on_remote_for(job).map(&:name) should match #files_sent_for(job).
  # If the files do not exist, or were removed by cycling, this will return [].
  def objects_on_remote_for(job)
    cloud_io.objects(remote_path_for(job)).sort_by(&:name)
  end

  def segments_on_remote_for(job)
    segments_cloud_io.objects(remote_path_for(job))
  end

  def clean_remote
    path = BackupSpec::LIVE['storage']['cloudfiles']['path']
    objects = cloud_io.objects(path)
    unless objects.empty?
      slo_objects, objects = objects.partition(&:slo?)
      cloud_io.delete_slo(slo_objects)
      cloud_io.delete(objects)
    end

    # in case segments are uploaded, but the manifest isn't
    objects = segments_cloud_io.objects(path)
    segments_cloud_io.delete(objects) unless objects.empty?
  end

end
end
