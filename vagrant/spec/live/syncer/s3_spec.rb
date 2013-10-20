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
describe Syncer::Cloud::S3,
    :if => BackupSpec::LIVE['syncer']['cloud']['s3']['specs_enabled'] == true do

  before { prepare_local_sync_files; clean_remote }
  after  { clean_remote }

  shared_examples 'sync test (s3)' do

    it 'works' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          config = BackupSpec::LIVE['syncer']['cloud']['s3']
          sync_with Cloud::S3 do |s3|
            s3.access_key_id      = config['access_key_id']
            s3.secret_access_key  = config['secret_access_key']
            s3.region             = config['region']
            s3.bucket             = config['bucket']
            s3.path               = config['path']
            s3.thread_count       = #{ use_threads ? 2 : 0 }
            s3.mirror             = #{ mirror }

            s3.directories do
              add File.join(BackupSpec::LOCAL_SYNC_PATH, 'dir_a')
              add File.join(BackupSpec::LOCAL_SYNC_PATH, 'dir_b')
            end
          end
        end
      EOS

      job = backup_perform :my_backup, :exit_status => 1

      expect(
        objects_on_remote.map {|obj| [obj.key, obj.etag] }
      ).to eq(
        expected_on_remote(:before_update, mirror)
      )

      expect( skipped_file_logged?(job) ).to be_true

      update_local_sync_files

      job = backup_perform :my_backup, :exit_status => 1
      objects = objects_on_remote

      expect(
        objects.map {|obj| [obj.key, obj.etag] }
      ).to eq(
        expected_on_remote(:after_update, mirror)
      )

      expect( skipped_file_logged?(job) ).to be_true

      expect(
        objects.all? {|obj| obj.storage_class == 'STANDARD' }
      ).to be(true)

      expect(
        objects.all? {|obj| obj.encryption.nil? }
      ).to be(true)
    end

  end # shared_examples 'sync test (s3)'

  context 'with threads', :live do
    let(:use_threads) { true }

    context 'with mirroring' do
      let(:mirror) { true }
      include_examples 'sync test (s3)'
    end

    context 'without mirroring' do
      let(:mirror) { false }
      include_examples 'sync test (s3)'
    end
  end

  context 'without threads', :live do
    let(:use_threads) { false }

    context 'with mirroring' do
      let(:mirror) { true }
      include_examples 'sync test (s3)'
    end

    context 'without mirroring' do
      let(:mirror) { false }
      include_examples 'sync test (s3)'
    end
  end

  it 'uses :storage_class and :encryption', :live do
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        config = BackupSpec::LIVE['syncer']['cloud']['s3']
        sync_with Cloud::S3 do |s3|
          s3.access_key_id      = config['access_key_id']
          s3.secret_access_key  = config['secret_access_key']
          s3.region             = config['region']
          s3.bucket             = config['bucket']
          s3.path               = config['path']
          s3.storage_class      = :reduced_redundancy
          s3.encryption         = :aes256

          s3.directories do
            add File.join(BackupSpec::LOCAL_SYNC_PATH, 'dir_a')
            add File.join(BackupSpec::LOCAL_SYNC_PATH, 'dir_b')
          end
        end
      end
    EOS

    backup_perform :my_backup, :exit_status => 1
    objects = objects_on_remote

    expect(
      objects.all? {|obj| obj.storage_class == 'REDUCED_REDUNDANCY' }
    ).to be(true)

    expect(
      objects.all? {|obj| obj.encryption == 'AES256' }
    ).to be_true
  end

  it 'excludes files', :live do
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        config = BackupSpec::LIVE['syncer']['cloud']['s3']
        sync_with Cloud::S3 do |s3|
          s3.access_key_id      = config['access_key_id']
          s3.secret_access_key  = config['secret_access_key']
          s3.region             = config['region']
          s3.bucket             = config['bucket']
          s3.path               = config['path']

          s3.directories do
            add File.join(BackupSpec::LOCAL_SYNC_PATH, 'dir_a')
            add File.join(BackupSpec::LOCAL_SYNC_PATH, 'dir_b')
            exclude '**/two.*'
            exclude /three\.file$/
          end
        end
      end
    EOS

    backup_perform :my_backup, :exit_status => 1

    expect(
      objects_on_remote.map {|obj| [obj.key, obj.etag] }
    ).to eq([
      [File.join(remote_path, 'dir_a/one.file'), 'd3b07384d113edec49eaa6238ad5ff00']
    ])
  end

  private

  def cloud_io
    config = BackupSpec::LIVE['syncer']['cloud']['s3']
    @cloud_io ||= CloudIO::S3.new(
      :access_key_id      => config['access_key_id'],
      :secret_access_key  => config['secret_access_key'],
      :region             => config['region'],
      :bucket             => config['bucket'],
      :max_retries        => 3,
      :retry_waitsec      => 5,
      # Syncers can not use multipart upload.
      :chunk_size         => 0
    )
  end

  def remote_path
    BackupSpec::LIVE['syncer']['cloud']['s3']['path']
  end

  def objects_on_remote
    cloud_io.objects(remote_path).sort_by(&:key)
  end

  def clean_remote
    cloud_io.delete(objects_on_remote)
  end

  def expected_on_remote(state, mirror)
    case state
    when :before_update
      files = [['dir_a/one.file',          'd3b07384d113edec49eaa6238ad5ff00'],
               ['dir_b/dir_c/three.file',  'd3b07384d113edec49eaa6238ad5ff00'],
               ['dir_b/two.file',          'd3b07384d113edec49eaa6238ad5ff00']]
    when :after_update
      files = [['dir_a/dir_d/two.new',     '14758f1afd44c09b7992073ccf00b43d'],
               ['dir_a/one.file',          '14758f1afd44c09b7992073ccf00b43d'],
               ['dir_b/dir_c/three.file',  'd3b07384d113edec49eaa6238ad5ff00'],
               ['dir_b/one.new',           '14758f1afd44c09b7992073ccf00b43d']]
      files << ['dir_b/two.file', 'd3b07384d113edec49eaa6238ad5ff00'] unless mirror
    end
    files.map {|path, md5| [File.join(remote_path, path), md5] }.sort_by(&:first)
  end

  def skipped_file_logged?(job)
    messages = job.logger.messages.map {|m| m.formatted_lines }.flatten
    file = File.join(BackupSpec::LOCAL_SYNC_PATH, "dir_b/bad\uFFFDfile")
    messages.any? {|line| line.include? "[warn]   [skipping] #{ file }" }
  end

end
end
