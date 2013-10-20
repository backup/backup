# encoding: utf-8

require File.expand_path('../../../spec_helper', __FILE__)

# To run these tests, you need to setup your Cloudfiles credentials in
#   /vagrant/spec/live.yml
#
# It's recommended you use a dedicated Container for this, like:
#   backup.testing.container
#
# Note: Expectations will occasionally fail due to eventual consistency.
module Backup
describe Syncer::Cloud::CloudFiles,
    :if => BackupSpec::LIVE['syncer']['cloud']['cloudfiles']['specs_enabled'] == true do

  before { prepare_local_sync_files; clean_remote }
  after  { clean_remote }

  shared_examples 'sync test (cf)' do

    it 'works' do
      create_model :my_backup, <<-EOS
        Backup::Model.new(:my_backup, 'a description') do
          config = BackupSpec::LIVE['syncer']['cloud']['cloudfiles']
          sync_with Cloud::CloudFiles do |cf|
            cf.username     = config['username']
            cf.api_key      = config['api_key']
            cf.auth_url     = config['auth_url']
            cf.region       = config['region']
            cf.servicenet   = config['servicenet']
            cf.container    = config['container']
            cf.path         = config['path']
            cf.thread_count = #{ use_threads ? 2 : 0 }
            cf.mirror       = #{ mirror }

            cf.directories do
              add File.join(BackupSpec::LOCAL_SYNC_PATH, 'dir_a')
              add File.join(BackupSpec::LOCAL_SYNC_PATH, 'dir_b')
            end
          end
        end
      EOS

      job = backup_perform :my_backup, :exit_status => 1

      expect(
        objects_on_remote.map {|obj| [obj.name, obj.hash] }
      ).to eq(
        expected_on_remote(:before_update, mirror)
      )
      expect( skipped_file_logged?(job) ).to be_true

      update_local_sync_files

      job = backup_perform :my_backup, :exit_status => 1

      expect(
        objects_on_remote.map {|obj| [obj.name, obj.hash] }
      ).to eq(
        expected_on_remote(:after_update, mirror)
      )
      expect( skipped_file_logged?(job) ).to be_true
    end

  end # shared_examples 'sync test (cf)'

  context 'with threads', :live do
    let(:use_threads) { true }

    context 'with mirroring' do
      let(:mirror) { true }
      include_examples 'sync test (cf)'
    end

    context 'without mirroring' do
      let(:mirror) { false }
      include_examples 'sync test (cf)'
    end
  end

  context 'without threads', :live do
    let(:use_threads) { false }

    context 'with mirroring' do
      let(:mirror) { true }
      include_examples 'sync test (cf)'
    end

    context 'without mirroring' do
      let(:mirror) { false }
      include_examples 'sync test (cf)'
    end
  end

  it 'excludes files', :live do
    create_model :my_backup, <<-EOS
      Backup::Model.new(:my_backup, 'a description') do
        config = BackupSpec::LIVE['syncer']['cloud']['cloudfiles']
        sync_with Cloud::CloudFiles do |cf|
          cf.username     = config['username']
          cf.api_key      = config['api_key']
          cf.auth_url     = config['auth_url']
          cf.region       = config['region']
          cf.servicenet   = config['servicenet']
          cf.container    = config['container']
          cf.path         = config['path']

          cf.directories do
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
      objects_on_remote.map {|obj| [obj.name, obj.hash] }
    ).to eq([
      [File.join(remote_path, 'dir_a/one.file'), 'd3b07384d113edec49eaa6238ad5ff00']
    ])
  end

  private

  def cloud_io
    config = BackupSpec::LIVE['syncer']['cloud']['cloudfiles']
    @cloud_io ||= CloudIO::CloudFiles.new(
      :username           => config['username'],
      :api_key            => config['api_key'],
      :auth_url           => config['auth_url'],
      :region             => config['region'],
      :servicenet         => config['servicenet'],
      :container          => config['container'],
      :max_retries        => 3,
      :retry_waitsec      => 5,
      # Syncers can not use multipart upload.
      :segments_container => nil,
      :segment_size       => 0
    )
  end

  def remote_path
    BackupSpec::LIVE['syncer']['cloud']['cloudfiles']['path']
  end

  def objects_on_remote
    cloud_io.objects(remote_path).sort_by(&:name)
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
