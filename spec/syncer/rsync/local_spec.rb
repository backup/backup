# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Syncer::RSync::Local do

  let(:rsync) do
    Backup::Syncer::RSync::Local.new do |rsync|
      rsync.path      = '~/backups/'
      rsync.mirror    = true
      rsync.additional_options = []

      rsync.directories do |directory|
        directory.add "/some/random/directory"
        directory.add "/another/random/directory"
      end
    end
  end

  before do
    Backup::Configuration::Syncer::RSync::Local.clear_defaults!
  end

  it 'should have defined the configuration properly' do
    rsync.path.should     == 'backups/'
    rsync.mirror.should   == "--delete"
  end

  it 'should use the defaults if a particular attribute has not been defined' do
    Backup::Configuration::Syncer::RSync::Local.defaults do |rsync|
      rsync.mirror   = false
    end

    rsync = Backup::Syncer::RSync::Local.new do |rsync|
      rsync.directories do |directory|
        directory.add "/some/random/directory"
        directory.add "/another/random/directory"
      end
    end

    rsync.mirror.should      == nil
    rsync.directories.should == "'/some/random/directory' '/another/random/directory'"
  end

  it 'should have its own defaults' do
    rsync = Backup::Syncer::RSync::Local.new
    rsync.path.should     == 'backups'
    rsync.mirror.should   == nil
    rsync.directories.should  == ''
    rsync.additional_options.should == []
  end

  describe '#mirror' do
    context 'when true' do
      it do
        rsync.mirror = true
        rsync.mirror.should == '--delete'
      end
    end

    context 'when nil/false' do
      it do
        rsync.mirror = nil
        rsync.mirror.should == nil
      end

      it do
        rsync.mirror = false
        rsync.mirror.should == nil
      end
    end
  end

  describe '#archive' do
    it do
      rsync.archive.should == '--archive'
    end
  end

  describe '#directories' do
    context 'when its empty' do
      it do
        rsync.directories = []
        rsync.directories.should == ''
      end
    end

    context 'when it has items' do
      it do
        rsync.directories = ['directory1', 'directory1/directory2', 'directory1/directory2/directory3']
        rsync.directories.should == "'directory1' 'directory1/directory2' 'directory1/directory2/directory3'"
      end
    end
  end

  describe '#options' do
    it do
      rsync.options.should == "--archive --delete"
    end
  end

  describe '#perform' do

    it 'should invoke the rsync command to transfer the files and directories' do
      Backup::Logger.expects(:message).with("Backup::Syncer::RSync::Local started syncing '/some/random/directory' '/another/random/directory'.")
      rsync.expects(:utility).with(:rsync).returns(:rsync)
      rsync.expects(:run).with("rsync --archive --delete " +
                               "'/some/random/directory' '/another/random/directory' 'backups/'")
      rsync.perform!
    end

    it 'should not pass in the --password-file option' do
      Backup::Logger.expects(:message).with("Backup::Syncer::RSync::Local started syncing '/some/random/directory' '/another/random/directory'.")
      rsync.expects(:utility).with(:rsync).returns(:rsync)
      rsync.expects(:run).with("rsync --archive --delete " +
                               "'/some/random/directory' '/another/random/directory' 'backups/'")
      rsync.perform!
    end
  end

end
