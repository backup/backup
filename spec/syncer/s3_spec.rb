# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Syncer::S3 do

  let(:s3) do
    Backup::Syncer::S3.new do |s3|
      s3.access_key_id      = 'my_access_key_id'
      s3.secret_access_key  = 'my_secret_access_key'
      s3.bucket             = 'my-bucket'
      s3.path               = "/backups"
      s3.mirror             = true

      s3.directories do |directory|
        directory.add "/some/random/directory"
        directory.add "/another/random/directory"
      end
    end
  end

  before do
    Backup::Configuration::Syncer::S3.clear_defaults!
  end

  it 'should have defined the configuration properly' do
    s3.access_key_id.should      == 'my_access_key_id'
    s3.secret_access_key.should  == 'my_secret_access_key'
    s3.bucket.should             == 'my-bucket'
    s3.path.should               == 'backups'
    s3.mirror.should             == '--delete'
    s3.directories.should        == ["/some/random/directory", "/another/random/directory"]
  end

  it 'should use the defaults if a particular attribute has not been defined' do
    Backup::Configuration::Syncer::S3.defaults do |s3|
      s3.access_key_id      = 'my_access_key_id'
      s3.bucket             = 'my-bucket'
      s3.path               = "/backups"
      s3.mirror             = true
    end

    s3 = Backup::Syncer::S3.new do |s3|
      s3.secret_access_key = 'some_secret_access_key'
      s3.mirror            = false
    end

    s3.access_key_id      = 'my_access_key_id'
    s3.secret_access_key  = 'some_secret_access_key'
    s3.bucket             = 'my-bucket'
    s3.path               = "/backups"
    s3.mirror             = false
  end

  it 'should have its own defaults' do
    s3 = Backup::Syncer::S3.new
    s3.path.should        == 'backups'
    s3.directories.should == Array.new
    s3.mirror.should      == nil
    s3.additional_options.should == []
  end

  describe '#mirror' do
    context 'when true' do
      it do
        s3.mirror = true
        s3.mirror.should == '--delete'
      end
    end

    context 'when nil/false' do
      it do
        s3.mirror = nil
        s3.mirror.should == nil
      end

      it do
        s3.mirror = false
        s3.mirror.should == nil
      end
    end
  end

  describe '#recursive' do
    it do
      s3.recursive.should == '--recursive'
    end
  end

  describe '#additional_options' do
    it do
      s3.additional_options = ['--exclude="*.rb"']
      s3.options.should == '--verbose --recursive --delete --exclude="*.rb"'
    end
  end

  describe '#verbose' do
    it do
      s3.verbose.should == '--verbose'
    end
  end

  describe '#directories' do
    context 'when its empty' do
      it do
        s3.directories         = []
        s3.directories.should == []
      end
    end

    context 'when it has items' do
      it do
        s3.directories         = ['directory1', 'directory1/directory2', 'directory1/directory2/directory3']
        s3.directories.should == ['directory1', 'directory1/directory2', 'directory1/directory2/directory3']
      end
    end
  end

  describe '#options' do
    it do
      s3.options.should == "--verbose --recursive --delete"
    end
  end

  describe '#perform' do
    before do
      # stub out the silent, because we're not testing logger logic here
      Backup::Logger.stubs(:silent)
    end

    it 'should sync two directories' do
      s3.expects(:utility).with(:s3sync).returns(:s3sync).twice

      Backup::Logger.expects(:message).with("Backup::Syncer::S3 started syncing '/some/random/directory'.")
      s3.expects(:run).with("s3sync --verbose --recursive --delete '/some/random/directory' 'my-bucket:backups'")

      Backup::Logger.expects(:message).with("Backup::Syncer::S3 started syncing '/another/random/directory'.")
      s3.expects(:run).with("s3sync --verbose --recursive --delete '/another/random/directory' 'my-bucket:backups'")

      s3.perform!
    end
  end

end
