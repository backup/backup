# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Storage::FTP do

  let(:ftp) do
    Backup::Storage::FTP.new do |ftp|
      ftp.username  = 'my_username'
      ftp.password  = 'my_password'
      ftp.ip        = '123.45.678.90'
      ftp.port      = 21
      ftp.path      = '~/backups/'
      ftp.keep      = 20
    end
  end

  before do
    Backup::Configuration::Storage::FTP.clear_defaults!
  end

  it 'should have defined the configuration properly' do
    ftp.username.should == 'my_username'
    ftp.password.should == 'my_password'
    ftp.ip.should       == '123.45.678.90'
    ftp.port.should     == 21
    ftp.path.should     == 'backups/'
    ftp.keep.should     == 20
  end

  it 'should use the defaults if a particular attribute has not been defined' do
    Backup::Configuration::Storage::FTP.defaults do |ftp|
      ftp.username = 'my_default_username'
      ftp.password = 'my_default_password'
      ftp.path     = '~/backups'
    end

    ftp = Backup::Storage::FTP.new do |ftp|
      ftp.password = 'my_password'
      ftp.ip       = '123.45.678.90'
    end

    ftp.username.should == 'my_default_username'
    ftp.password.should == 'my_password'
    ftp.ip.should       == '123.45.678.90'
    ftp.port.should     == 21
  end

  it 'should have its own defaults' do
    ftp = Backup::Storage::FTP.new
    ftp.port.should == 21
    ftp.path.should == 'backups'
  end

  describe '#connection' do
    it 'should establish a connection to the remote server using the provided ip address and credentials' do
      Net::FTP.expects(:new).with('123.45.678.90', 'my_username', 'my_password')
      ftp.send(:connection)
    end

    it 'should re-define the Net::FTP port' do
      Net::FTP.stubs(:new)
      ftp.port = 40
      ftp.send(:connection)
      Net::FTP::FTP_PORT.should == 40
    end
  end

  describe '#transfer!' do
    let(:connection) { mock('Fog::Storage') }

    before do
      Net::FTP.stubs(:new).returns(connection)
      ftp.stubs(:create_remote_directories!)
      Backup::Logger.stubs(:message)
    end

    it 'should transfer the provided file to the path' do
      Backup::Model.new('blah', 'blah') {}
      file = mock("Backup::Storage::FTP::File")

      ftp.expects(:create_remote_directories!)
      connection.expects(:put).with(
        File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar"),
        File.join('backups/myapp', "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar")
      )

      ftp.send(:transfer!)
    end
  end

  describe '#remove!' do
    let(:connection) { mock('Net::FTP') }

    before do
      Net::FTP.stubs(:new).returns(connection)
    end

    it 'should remove the file from the remote server path' do
      connection.expects(:delete).with("backups/myapp/#{ Backup::TIME }.#{ Backup::TRIGGER }.tar")
      ftp.send(:remove!)
    end
  end

  describe '#create_remote_directories!' do
    let(:connection) { mock('Net::FTP') }

    before do
      Net::FTP.stubs(:new).returns(connection)
    end

    it 'should properly create remote directories one by one' do
      ftp.path = '~/backups/some_other_folder/another_folder'

      connection.expects(:mkdir).with('~')
      connection.expects(:mkdir).with('~/backups')
      connection.expects(:mkdir).with('~/backups/some_other_folder')
      connection.expects(:mkdir).with('~/backups/some_other_folder/another_folder')
      connection.expects(:mkdir).with('~/backups/some_other_folder/another_folder/myapp')

      ftp.send(:create_remote_directories!)
    end
  end

  describe '#perform' do
    it 'should invoke transfer! and cycle!' do
      ftp.expects(:transfer!)
      ftp.expects(:cycle!)
      ftp.perform!
    end
  end

end
