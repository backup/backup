# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Storage::CloudFiles do

  let(:cf) do
    Backup::Storage::CloudFiles.new do |cf|
      cf.username  = 'my_username'
      cf.api_key   = 'my_api_key'
      cf.container = 'my_container'
      cf.path      = 'backups'
      cf.keep      = 20
      cf.auth_url  = 'lon.auth.api.rackspacecloud.com'
    end
  end

  before do
    Backup::Configuration::Storage::CloudFiles.clear_defaults!
  end

  it 'should have defined the configuration properly' do
    cf.username.should  == 'my_username'
    cf.api_key.should   == 'my_api_key'
    cf.container.should == 'my_container'
    cf.path.should      == 'backups'
    cf.keep.should      == 20
    cf.auth_url.should  == 'lon.auth.api.rackspacecloud.com'
  end

  it 'should use the defaults if a particular attribute has not been defined' do
    Backup::Configuration::Storage::CloudFiles.defaults do |cf|
      cf.username = 'my_username'
      cf.api_key  = 'my_api_key'
    end

    cf = Backup::Storage::CloudFiles.new do |cf|
      cf.container = 'my_container'
      cf.path      = 'my/backups'
    end

    cf.username.should  == 'my_username'
    cf.api_key.should   == 'my_api_key'
    cf.container.should == 'my_container'
    cf.path.should      == 'my/backups'
  end

  describe '#connection' do
    it 'should establish a connection to Rackspace Cloud Files. using the provided credentials' do
      Fog::Storage.expects(:new).with({
        :provider           => 'Rackspace',
        :rackspace_username => 'my_username',
        :rackspace_api_key  => 'my_api_key',
        :rackspace_auth_url => 'lon.auth.api.rackspacecloud.com'
      })

      cf.send(:connection)
    end
  end

  describe '#provider' do
    it 'should be Rackspace' do
      cf.provider == 'Rackspace'
    end
  end

  describe '#transfer!' do
    let(:connection) { mock('Fog::Storage') }
    before do
      Fog::Storage.stubs(:new).returns(connection)
    end

    it 'should transfer the provided file to the container' do
      Backup::Model.new('blah', 'blah') {}
      file = mock("Backup::Storage::CloudFiles::File")
      File.expects(:open).with("#{File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER}")}.tar").returns(file)
      connection.expects(:put_object).with('my_container', "backups/myapp/#{ Backup::TIME }/#{ Backup::TRIGGER }.tar", file)
      cf.send(:transfer!)
    end
  end

  describe '#remove!' do
    let(:connection) { mock('Fog::Storage') }
    before do
      Fog::Storage.stubs(:new).returns(connection)
    end

    it 'should remove the file from the container' do
      connection.expects(:delete_object).with('my_container', "backups/myapp/#{ Backup::TIME }/#{ Backup::TRIGGER }.tar")
      cf.send(:remove!)
    end
  end

  describe '#perform' do
    it 'should invoke transfer! and cycle!' do
      cf.expects(:transfer!)
      cf.expects(:cycle!)
      cf.perform!
    end
  end

end
