# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Syncer::RSync do

  let(:rsync) do
    Backup::Syncer::RSync.new do |rsync|
      rsync.username  = 'my_username'
      rsync.password  = 'my_password'
      rsync.ip        = '123.45.678.90'
      rsync.port      = 22
      rsync.path      = '~/backups/'
      rsync.mirror    = true
      rsync.compress  = true
      rsync.additional_options = []

      rsync.folders do |folder|
        folder.add "/some/random/folder"
        folder.add "/another/random/folder"
      end
    end
  end

  before do
    Backup::Configuration::Syncer::RSync.clear_defaults!
  end

  it 'should have defined the configuration properly' do
    rsync.username.should == 'my_username'
    rsync.password.should == 'my_password'
    rsync.ip.should       == '123.45.678.90'
    rsync.port.should     == "--port='22'"
    rsync.path.should     == 'backups/'
    rsync.mirror.should   == "--delete"
    rsync.compress.should == "-z"
  end

  it 'should use the defaults if a particular attribute has not been defined' do
    Backup::Configuration::Syncer::RSync.defaults do |rsync|
      rsync.username = 'my_default_username'
      rsync.password = 'my_default_password'
      rsync.path     = '~/backups'
      rsync.mirror   = false
    end

    rsync = Backup::Syncer::RSync.new do |rsync|
      rsync.password = 'my_password'
      rsync.ip       = '123.45.678.90'
      rsync.compress = false
    end

    rsync.username.should == 'my_default_username'
    rsync.password.should == 'my_password'
    rsync.ip.should       == '123.45.678.90'
    rsync.port.should     == "--port='22'"
    rsync.mirror.should   == nil
    rsync.compress.should == nil
  end

  it 'should have its own defaults' do
    rsync = Backup::Syncer::RSync.new
    rsync.port.should     == "--port='22'"
    rsync.path.should     == 'backups'
    rsync.compress.should == nil
    rsync.mirror.should   == nil
    rsync.folders.should  == ''
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

  describe '#compress' do
    context 'when true' do
      it do
        rsync.compress = true
        rsync.compress.should == '-z'
      end
    end

    context 'when nil/false' do
      it do
        rsync.compress = nil
        rsync.compress.should == nil
      end

      it do
        rsync.compress = false
        rsync.compress.should == nil
      end
    end
  end

  describe '#archive' do
    it do
      rsync.archive.should == '--archive'
    end
  end

  describe '#port' do
    it do
      rsync.port.should == "--port='22'"
    end
  end

  describe '#folders' do
    context 'when its empty' do
      it do
        rsync.folders = []
        rsync.folders.should == ''
      end
    end

    context 'when it has items' do
      it do
        rsync.folders = ['folder1', 'folder1/folder2', 'folder1/folder2/folder3']
        rsync.folders.should == "'folder1' 'folder1/folder2' 'folder1/folder2/folder3'"
      end
    end
  end

  describe '#options' do
    it do
      rsync.options.should == "--archive --delete -z --port='22'"
    end
  end

  describe '#perform' do
    it 'should invoke transfer!' do
      Backup::Logger.expects(:message).with("Backup::Syncer::RSync started syncing '/some/random/folder' '/another/random/folder'.")
      rsync.expects(:utility).with(:rsync).returns(:rsync)
      rsync.expects(:run).with("rsync -vhP --archive --delete -z --port='22' '/some/random/folder' '/another/random/folder' 'my_username@123.45.678.90:backups/'")
      rsync.perform!
    end
  end

end
