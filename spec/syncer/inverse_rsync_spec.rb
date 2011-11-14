# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Syncer::InverseRSync do

  let(:inverse_rsync) do
    Backup::Syncer::InverseRSync.new do |inverse_rsync|
      inverse_rsync.username    = 'my_username'
      inverse_rsync.password    = 'my_password'
      inverse_rsync.ip          = '123.45.678.90'
      inverse_rsync.port        = 22
      inverse_rsync.remote_path = '/tmp'
      inverse_rsync.path        = '~/backups/'
      inverse_rsync.mirror      = true
      inverse_rsync.compress    = true
      inverse_rsync.additional_options = []
    end
  end

  before do
    Backup::Configuration::Syncer::InverseRSync.clear_defaults!
  end

  it 'should have defined the configuration properly' do
    inverse_rsync.username.should    == 'my_username'
    inverse_rsync.password.should    =~ /backup-rsync-password/
    inverse_rsync.ip.should          == '123.45.678.90'
    inverse_rsync.port.should        == "-e 'ssh -p 22'"
    inverse_rsync.path.should        == 'backups/'
    inverse_rsync.remote_path.should == '/tmp'
    inverse_rsync.mirror.should      == "--delete"
    inverse_rsync.compress.should    == "--compress"

    File.read(inverse_rsync.instance_variable_get('@password_file').path).should == 'my_password'
  end

  it 'should use the defaults if a particular attribute has not been defined' do
    Backup::Configuration::Syncer::InverseRSync.defaults do |inverse_rsync|
      inverse_rsync.username = 'my_default_username'
      inverse_rsync.password = 'my_default_password'
      inverse_rsync.path     = '~/backups'
      inverse_rsync.mirror   = false
    end

    inverse_rsync = Backup::Syncer::InverseRSync.new do |inverse_rsync|
      inverse_rsync.password = 'my_password'
      inverse_rsync.ip       = '123.45.678.90'
      inverse_rsync.compress = false
    end

    inverse_rsync.username.should == 'my_default_username'
    inverse_rsync.password.should =~ /backup-rsync-password/
    inverse_rsync.ip.should       == '123.45.678.90'
    inverse_rsync.port.should     == "-e 'ssh -p 22'"
    inverse_rsync.mirror.should   == nil
    inverse_rsync.compress.should == nil

    File.read(inverse_rsync.instance_variable_get('@password_file').path).should == 'my_password'
  end

  it 'should have its own defaults' do
    inverse_rsync = Backup::Syncer::InverseRSync.new
    inverse_rsync.port.should     == "-e 'ssh -p 22'"
    inverse_rsync.path.should     == 'backups'
    inverse_rsync.compress.should == nil
    inverse_rsync.mirror.should   == nil
    inverse_rsync.directories.should  == ''
    inverse_rsync.additional_options.should == []
  end

  describe '#mirror' do
    context 'when true' do
      it do
        inverse_rsync.mirror = true
        inverse_rsync.mirror.should == '--delete'
      end
    end

    context 'when nil/false' do
      it do
        inverse_rsync.mirror = nil
        inverse_rsync.mirror.should == nil
      end

      it do
        inverse_rsync.mirror = false
        inverse_rsync.mirror.should == nil
      end
    end
  end

  describe '#compress' do
    context 'when true' do
      it do
        inverse_rsync.compress = true
        inverse_rsync.compress.should == '--compress'
      end
    end

    context 'when nil/false' do
      it do
        inverse_rsync.compress = nil
        inverse_rsync.compress.should == nil
      end

      it do
        inverse_rsync.compress = false
        inverse_rsync.compress.should == nil
      end
    end
  end

  describe '#archive' do
    it do
      inverse_rsync.archive.should == '--archive'
    end
  end

  describe '#port' do
    it do
      inverse_rsync.port.should == "-e 'ssh -p 22'"
    end
  end

  describe '#directories' do
    context 'when its empty' do
      it do
        inverse_rsync.directories = []
        inverse_rsync.directories.should == ''
      end
    end

    context 'when it has items' do
      it do
        inverse_rsync.directories = ['directory1', 'directory1/directory2', 'directory1/directory2/directory3']
        inverse_rsync.directories.should == "'directory1' 'directory1/directory2' 'directory1/directory2/directory3'"
      end
    end
  end

  describe '#options' do
    it do
      inverse_rsync.options.should == "--archive --delete --compress -e 'ssh -p 22' " +
                              "--password-file='#{inverse_rsync.instance_variable_get('@password_file').path}'"
    end
  end

  describe '#password' do
    before do
      inverse_rsync.stubs(:utility).with(:rsync).returns(:inverse_rsync)
      inverse_rsync.stubs(:run)
    end

    it do
      inverse_rsync.password = 'my_password'
      inverse_rsync.expects(:remove_password_file!)

      inverse_rsync.perform!
    end

    it do
      inverse_rsync.password = nil
      inverse_rsync.expects(:remove_password_file!)

      inverse_rsync.perform!
    end
  end

  describe '#perform' do

    it 'should invoke the inverse_rsync command to transfer the files and directories' do
      Backup::Logger.expects(:message).with("Backup::Syncer::InverseRSync started syncing '/tmp'.")
      inverse_rsync.expects(:run).with("mkdir -p backups/")
      inverse_rsync.expects(:utility).with(:rsync).returns(:rsync)
      inverse_rsync.expects(:remove_password_file!)
      inverse_rsync.expects(:run).with("rsync -vhPr --archive --delete --compress -e 'ssh -p 22' --password-file='#{inverse_rsync.instance_variable_get('@password_file').path}' " +
                               "'my_username@123.45.678.90:/tmp' 'backups/'")
      inverse_rsync.perform!
    end

    it 'should not pass in the --password-file option' do
      Backup::Logger.expects(:message).with("Backup::Syncer::InverseRSync started syncing '/tmp'.")
      inverse_rsync.password = nil
      inverse_rsync.expects(:run).with("mkdir -p backups/")
      inverse_rsync.expects(:utility).with(:rsync).returns(:rsync)
      inverse_rsync.expects(:remove_password_file!)
      inverse_rsync.expects(:run).with("rsync -vhPr --archive --delete --compress -e 'ssh -p 22' " +
                               "'my_username@123.45.678.90:/tmp' 'backups/'")
      inverse_rsync.perform!
    end
  end

end
