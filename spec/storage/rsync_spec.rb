# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Storage::RSync do

  let(:rsync) do
    Backup::Storage::RSync.new do |rsync|
      rsync.username  = 'my_username'
      rsync.password  = 'my_password'
      rsync.ip        = '123.45.678.90'
      rsync.port      = 22
      rsync.path      = '~/backups/'
    end
  end

  before do
    Backup::Configuration::Storage::RSync.clear_defaults!
  end

  it 'should have defined the configuration properly' do
    rsync.username.should        == 'my_username'
    rsync.send(:password).should =~ /backup-rsync-password/
    rsync.ip.should              == '123.45.678.90'
    rsync.port.should            == 22
    rsync.path.should            == 'backups/'

    File.read(rsync.instance_variable_get('@password_file').path).should == 'my_password'
  end

  it 'should use the defaults if a particular attribute has not been defined' do
    Backup::Configuration::Storage::RSync.defaults do |rsync|
      rsync.username = 'my_default_username'
      rsync.password = 'my_default_password'
      rsync.path     = '~/backups'
    end

    rsync = Backup::Storage::RSync.new do |rsync|
      rsync.password = 'my_password'
      rsync.ip       = '123.45.678.90'
    end

    rsync.username.should        == 'my_default_username'
    rsync.send(:password).should =~ /backup-rsync-password/
    rsync.ip.should              == '123.45.678.90'
    rsync.port.should            == 22

    File.read(rsync.instance_variable_get('@password_file').path).should == 'my_password'
  end

  it 'should have its own defaults' do
    rsync = Backup::Storage::RSync.new
    rsync.port.should == 22
    rsync.path.should == 'backups'
  end

  describe '#connection' do
    it 'should establish a connection to the remote server using the provided ip address and credentials' do
      Net::SSH.expects(:start).with('123.45.678.90', 'my_username', :password => 'my_password', :port => 22)
      rsync.send(:connection)
    end
  end

  describe '#transfer!' do
    let(:connection) { mock('Net::SCP') }

    before do
      Net::SSH.stubs(:start).returns(connection)
      rsync.stubs(:create_remote_directories!)
      Backup::Logger.stubs(:message)
    end

    it 'should transfer the provided file to the path' do
      Backup::Model.new('blah', 'blah') {}
      file = mock("Backup::Storage::RSync::File")

      rsync.expects(:create_remote_directories!)
      rsync.expects(:utility).returns('rsync')
      rsync.expects(:run).with("rsync -z --port='22' --password-file='#{rsync.instance_variable_get('@password_file').path}' '#{ File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar") }' 'my_username@123.45.678.90:backups/#{ Backup::TRIGGER }/#{ Backup::TRIGGER }.tar'")

      rsync.send(:transfer!)
    end

    it 'should not provide the --password-file option' do
      Backup::Model.new('blah', 'blah') {}
      file = mock("Backup::Storage::RSync::File")

      rsync.password = nil
      rsync.expects(:create_remote_directories!)
      rsync.expects(:utility).returns('rsync')
      rsync.expects(:run).with("rsync -z --port='22'  '#{ File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar") }' 'my_username@123.45.678.90:backups/#{ Backup::TRIGGER }/#{ Backup::TRIGGER }.tar'")

      rsync.send(:transfer!)
    end
  end

  describe '#remove!' do
    let(:connection) { mock('Net::SCP') }

    before do
      Net::SSH.stubs(:start).returns(connection)
    end

    it 'should remove the file from the remote server path' do
      connection.expects(:exec!).with("rm backups/myapp/#{ Backup::TIME }.#{ Backup::TRIGGER }.tar")
      rsync.send(:remove!)
    end
  end

  describe '#create_remote_directories!' do
    let(:connection) { mock('Net::SSH') }

    before do
      Net::SSH.stubs(:start).returns(connection)
    end

    it 'should properly create remote directories one by one' do
      rsync.path = 'backups/some_other_folder/another_folder'
      connection.expects(:exec!).with("mkdir -p 'backups/some_other_folder/another_folder/myapp'")
      rsync.send(:create_remote_directories!)
    end
  end

  describe '#perform' do
    it 'should invoke transfer!' do
      rsync.expects(:transfer!)
      rsync.perform!
    end
  end

end
