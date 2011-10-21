# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Storage::SFTP do

  let(:sftp) do
    Backup::Storage::SFTP.new do |sftp|
      sftp.username  = 'my_username'
      sftp.password  = 'my_password'
      sftp.ip        = '123.45.678.90'
      sftp.port      = 22
      sftp.path      = '~/backups/'
      sftp.keep      = 20
    end
  end

  before do
    Backup::Configuration::Storage::SFTP.clear_defaults!
  end

  it 'should have defined the configuration properly' do
    sftp.username.should == 'my_username'
    sftp.password.should == 'my_password'
    sftp.ip.should       == '123.45.678.90'
    sftp.port.should     == 22
    sftp.path.should     == 'backups/'
    sftp.keep.should     == 20
  end

  it 'should use the defaults if a particular attribute has not been defined' do
    Backup::Configuration::Storage::SFTP.defaults do |sftp|
      sftp.username = 'my_default_username'
      sftp.password = 'my_default_password'
      sftp.path     = '~/backups'
    end

    sftp = Backup::Storage::SFTP.new do |sftp|
      sftp.password = 'my_password'
      sftp.ip       = '123.45.678.90'
    end

    sftp.username.should == 'my_default_username'
    sftp.password.should == 'my_password'
    sftp.ip.should       == '123.45.678.90'
    sftp.port.should     == 22
  end

  it 'should have its own defaults' do
    sftp = Backup::Storage::SFTP.new
    sftp.port.should == 22
    sftp.path.should == 'backups'
  end

  describe '#connection' do
    it 'should establish a connection to the remote server using the provided ip address and credentials' do
      Net::SFTP.expects(:start).with('123.45.678.90', 'my_username', :password => 'my_password', :port => 22)
      sftp.send(:connection)
    end
  end

  describe '#transfer!' do
    let(:connection) { mock('Fog::Storage') }

    before do
      Net::SFTP.stubs(:start).returns(connection)
      sftp.stubs(:create_remote_directories!)
    end

    it 'should transfer the provided file to the path' do
      Backup::Model.new('blah', 'blah') {}
      file = mock("Backup::Storage::SFTP::File")

      sftp.expects(:create_remote_directories!)
      connection.expects(:upload!).with(
        File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar"),
        File.join('backups/myapp', Backup::TIME, "#{ Backup::TRIGGER }.tar")
      )

      sftp.send(:transfer!)
    end
  end

  describe '#remove!' do
    let(:connection) { mock('Net::SFTP') }

    before do
      Net::SFTP.stubs(:start).returns(connection)
    end

    it 'should remove the file from the remote server path' do
      connection.expects(:remove!).with("backups/myapp/#{ Backup::TIME }/#{ Backup::TRIGGER }.tar")
      sftp.send(:remove!)
    end
  end

  describe '#create_remote_directories!' do
    let(:connection) { mock('Net::SFTP') }

    before do
      Net::SFTP.stubs(:start).returns(connection)
    end

    it 'should properly create remote directories one by one' do
      sftp.path = 'backups/some_other_folder/another_folder'

      connection.expects(:mkdir!).with("backups")
      connection.expects(:mkdir!).with("backups/some_other_folder")
      connection.expects(:mkdir!).with("backups/some_other_folder/another_folder")
      connection.expects(:mkdir!).with("backups/some_other_folder/another_folder/myapp")
      connection.expects(:mkdir!).with("backups/some_other_folder/another_folder/myapp/#{ Backup::TIME }")

      sftp.send(:create_remote_directories!)
    end
  end

  describe '#perform' do
    it 'should invoke transfer! and cycle!' do
      sftp.expects(:transfer!)
      sftp.expects(:cycle!)
      sftp.perform!
    end
  end

end
