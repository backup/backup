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

      rsync.directories do |directory|
        directory.add "/some/random/directory"
        directory.add "/another/random/directory"
      end
    end
  end

  before do
    Backup::Configuration::Syncer::RSync.clear_defaults!
  end

  it 'should have defined the configuration properly' do
    rsync.username.should == 'my_username'
    rsync.password.should =~ /backup-rsync-password/
    rsync.ip.should       == '123.45.678.90'
    rsync.port.should     == "-e 'ssh -p 22'"
    rsync.path.should     == 'backups/'
    rsync.mirror.should   == "--delete"
    rsync.compress.should == "--compress"

    File.read(rsync.instance_variable_get('@password_file').path).should == 'my_password'
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
    rsync.password.should =~ /backup-rsync-password/
    rsync.ip.should       == '123.45.678.90'
    rsync.port.should     == "-e 'ssh -p 22'"
    rsync.mirror.should   == nil
    rsync.compress.should == nil

    File.read(rsync.instance_variable_get('@password_file').path).should == 'my_password'
  end

  it 'should have its own defaults' do
    rsync = Backup::Syncer::RSync.new
    rsync.port.should     == "-e 'ssh -p 22'"
    rsync.path.should     == 'backups'
    rsync.compress.should == nil
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

  describe '#compress' do
    context 'when true' do
      it do
        rsync.compress = true
        rsync.compress.should == '--compress'
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
      rsync.port.should == "-e 'ssh -p 22'"
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
      rsync.options.should == "--archive --delete --compress -e 'ssh -p 22' " +
                              "--password-file='#{rsync.instance_variable_get('@password_file').path}'"
    end
  end

  describe '#password' do
    before do
      rsync.stubs(:utility).with(:rsync).returns(:rsync)
      rsync.stubs(:run)
    end

    it do
      rsync.password = 'my_password'
      rsync.expects(:remove_password_file!)

      rsync.perform!
    end

    it do
      rsync.password = nil
      rsync.expects(:remove_password_file!)

      rsync.perform!
    end
  end

  describe '#perform' do

    it 'should invoke the rsync command to transfer the files and directories' do
      Backup::Logger.expects(:message).with("Backup::Syncer::RSync started syncing '/some/random/directory' '/another/random/directory'.")
      rsync.expects(:utility).with(:rsync).returns(:rsync)
      rsync.expects(:remove_password_file!)
      rsync.expects(:run).with("rsync --archive --delete --compress -e 'ssh -p 22' --password-file='#{rsync.instance_variable_get('@password_file').path}' " +
                               "'/some/random/directory' '/another/random/directory' 'my_username@123.45.678.90:backups/'")
      rsync.perform!
    end

    it 'should not pass in the --password-file option' do
      Backup::Logger.expects(:message).with("Backup::Syncer::RSync started syncing '/some/random/directory' '/another/random/directory'.")
      rsync.password = nil
      rsync.expects(:utility).with(:rsync).returns(:rsync)
      rsync.expects(:remove_password_file!)
      rsync.expects(:run).with("rsync --archive --delete --compress -e 'ssh -p 22' " +
                               "'/some/random/directory' '/another/random/directory' 'my_username@123.45.678.90:backups/'")
      rsync.perform!
    end
  end

end
