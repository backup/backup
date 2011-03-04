# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Storage::SCP do

  let(:scp) do
    Backup::Storage::SCP.new do |scp|
      scp.username  = 'my_username'
      scp.password  = 'my_password'
      scp.ip        = '123.45.678.90'
      scp.port      = 22
      scp.path      = '~/backups/'
      scp.keep      = 20
    end
  end

  before do
    Backup::Configuration::Storage::SFTP.clear_defaults!
  end

  it 'should have defined the configuration properly' do
    scp.username.should == 'my_username'
    scp.password.should == 'my_password'
    scp.ip.should       == '123.45.678.90'
    scp.port.should     == 22
    scp.path.should     == 'backups/'
    scp.keep.should     == 20
  end

  it 'should use the defaults if a particular attribute has not been defined' do
    Backup::Configuration::Storage::SCP.defaults do |scp|
      scp.username = 'my_default_username'
      scp.password = 'my_default_password'
      scp.path     = '~/backups'
    end

    scp = Backup::Storage::SCP.new do |scp|
      scp.password = 'my_password'
      scp.ip       = '123.45.678.90'
    end

    scp.username.should == 'my_default_username'
    scp.password.should == 'my_password'
    scp.ip.should       == '123.45.678.90'
    scp.port.should     == nil
  end

  describe '#connection' do
    it 'should establish a connection to the remote server using the provided ip address and credentials' do
      Net::SSH.expects(:start).with('123.45.678.90', 'my_username', :password => 'my_password', :port => 22)
      scp.send(:connection)
    end
  end

  describe '#transfer!' do
    let(:connection) { mock('Net::SCP') }

    before do
      Net::SSH.stubs(:start).returns(connection)
      scp.stubs(:create_remote_directories!)
      Backup::Logger.stubs(:message)
    end

    it 'should transfer the provided file to the path' do
      Backup::Model.new('blah', 'blah') {}
      file = mock("Backup::Storage::SCP::File")

      scp.expects(:create_remote_directories!)

      ssh_scp = mock('Net::SSH::SCP')
      connection.expects(:scp).returns(ssh_scp)

      ssh_scp.expects(:upload!).with(
        File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar"),
        File.join('backups/myapp', "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar")
      )

      scp.send(:transfer!)
    end
  end

  describe '#remove!' do
    let(:connection) { mock('Net::SCP') }

    before do
      Net::SSH.stubs(:start).returns(connection)
    end

    it 'should remove the file from the remote server path' do
      connection.expects(:exec!).with("rm backups/myapp/#{ Backup::TIME }.#{ Backup::TRIGGER }.tar")
      scp.send(:remove!)
    end
  end

  describe '#create_remote_directories!' do
    let(:connection) { mock('Net::SSH') }

    before do
      Net::SSH.stubs(:start).returns(connection)
    end

    it 'should properly create remote directories one by one' do
      scp.path = 'backups/some_other_folder/another_folder'

      connection.expects(:exec!).with("mkdir 'backups'")
      connection.expects(:exec!).with("mkdir 'backups/some_other_folder'")
      connection.expects(:exec!).with("mkdir 'backups/some_other_folder/another_folder'")
      connection.expects(:exec!).with("mkdir 'backups/some_other_folder/another_folder/myapp'")

      scp.send(:create_remote_directories!)
    end
  end

  describe '#perform' do
    it 'should invoke transfer! and cycle!' do
      scp.expects(:transfer!)
      scp.expects(:cycle!)
      scp.perform!
    end
  end

end
