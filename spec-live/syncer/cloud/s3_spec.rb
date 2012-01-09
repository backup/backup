# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe 'Syncer::Cloud::S3 - No Concurrency',
    :if => Backup::SpecLive::CONFIG['syncer']['cloud']['s3']['specs_enabled'] do
  let(:trigger) { 'syncer_cloud_s3' }
  let(:model) { h_set_trigger(trigger) }

  before do
    model # trigger model initialization so Fog is available
    create_sync_files
    clean_remote
  end

  after do
    clean_sync_dir
    clean_remote
  end

  it 'should work' do
    model.perform!
    remote_files.map {|file| [file.key, file.etag] }.sort.should == [
      ["backups/dir_a/one.file",          "d3b07384d113edec49eaa6238ad5ff00"],
      ["backups/dir_b/dir_c/three.file",  "d3b07384d113edec49eaa6238ad5ff00"],
      ["backups/dir_b/two.file",          "d3b07384d113edec49eaa6238ad5ff00"]
    ]

    update_sync_files

    model.perform!
    remote_files.map {|file| [file.key, file.etag] }.sort.should == [
      ["backups/dir_a/dir_d/two.new",     "14758f1afd44c09b7992073ccf00b43d"],
      ["backups/dir_a/one.file",          "14758f1afd44c09b7992073ccf00b43d"],
      ["backups/dir_b/dir_c/three.file",  "d3b07384d113edec49eaa6238ad5ff00"],
      ["backups/dir_b/one.new",           "14758f1afd44c09b7992073ccf00b43d"]
    ]
  end

  private

  ##
  # Initial Files are MD5: d3b07384d113edec49eaa6238ad5ff00
  #
  # ├── dir_a
  # │   └── one.file
  # └── dir_b
  #     ├── dir_c
  #     │   └── three.file
  #     ├── bad\xFFfile
  #     └── two.file
  def create_sync_files
    clean_sync_dir

    %w{ dir_a dir_b/dir_c }.each do |dir|
      path = File.join(Backup::SpecLive::SYNC_PATH, dir)
      FileUtils.mkdir_p(path)
    end

    %W{ dir_a/one.file
        dir_b/two.file
        dir_b/bad\xFFfile
        dir_b/dir_c/three.file }.each do |file|
      path = File.join(Backup::SpecLive::SYNC_PATH, file)
      File.open(path, 'w') {|file| file.puts 'foo' }
    end
  end

  ##
  # Added/Updated Files are MD5: 14758f1afd44c09b7992073ccf00b43d
  #
  # ├── dir_a
  # │   ├── dir_d           (add)
  # │   │   └── two.new     (add)
  # │   └── one.file        (update)
  # └── dir_b
  #     ├── dir_c
  #     │   └── three.file
  #     ├── bad\377file
  #     ├── one.new         (add)
  #     └── two.file        (remove)
  def update_sync_files
    FileUtils.mkdir_p(File.join(Backup::SpecLive::SYNC_PATH, 'dir_a/dir_d'))
    %w{ dir_a/one.file
        dir_b/one.new
        dir_a/dir_d/two.new }.each do |file|
      path = File.join(Backup::SpecLive::SYNC_PATH, file)
      File.open(path, 'w') {|file| file.puts 'foobar' }
    end

    path = File.join(Backup::SpecLive::SYNC_PATH, 'dir_b/two.file')
    h_safety_check(path)
    FileUtils.rm(path)
  end

  def clean_sync_dir
    path = Backup::SpecLive::SYNC_PATH
    if File.directory?(path)
      h_safety_check(path)
      FileUtils.rm_r(path)
    end
  end

  # use a new connection for each request
  def connection
    @opts = Backup::SpecLive::CONFIG['syncer']['cloud']['s3']
    Fog::Storage.new(
      :provider              => 'AWS',
      :aws_access_key_id     => @opts['access_key_id'],
      :aws_secret_access_key => @opts['secret_access_key'],
      :region                => @opts['region']
    )
  end

  def remote_files
    bucket = connection.directories.get(@opts['bucket'])
    bucket.files.all(:prefix => 'backups')
  end

  def clean_remote
    remote_files.each {|file| file.destroy }
  end

end
