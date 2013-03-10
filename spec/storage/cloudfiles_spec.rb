# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::CloudFiles do
  let(:model)   { Backup::Model.new(:test_trigger, 'test label') }
  let(:storage) do
    Backup::Storage::CloudFiles.new(model) do |cf|
      cf.username  = 'my_username'
      cf.api_key   = 'my_api_key'
      cf.auth_url  = 'lon.auth.api.rackspacecloud.com'
      cf.container = 'my_container'
      cf.keep      = 5
    end
  end

  it 'should be a subclass of Storage::OpenStack' do
    Backup::Storage::CloudFiles.
      superclass.should == Backup::Storage::OpenStack
  end

  describe '#initialize' do
    after { Backup::Storage::CloudFiles.clear_defaults! }

    it 'should load pre-configured defaults through Base' do
      Backup::Storage::CloudFiles.any_instance.expects(:load_defaults!)
      storage
    end

    it 'should pass the model reference to Base' do
      storage.instance_variable_get(:@model).should == model
    end

    it 'should pass the storage_id to Base' do
      storage = Backup::Storage::CloudFiles.new(model, 'my_storage_id')
      storage.storage_id.should == 'my_storage_id'
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        storage.username.should   == 'my_username'
        storage.api_key.should    == 'my_api_key'
        storage.auth_url.should   == 'lon.auth.api.rackspacecloud.com'
        storage.container.should  == 'my_container'
        storage.servicenet.should == false
        storage.path.should       == 'backups'

        storage.storage_id.should be_nil
        storage.keep.should       == 5
      end

      it 'should use default values if none are given' do
        storage = Backup::Storage::CloudFiles.new(model)

        storage.username.should   be_nil
        storage.api_key.should    be_nil
        storage.auth_url.should   be_nil
        storage.container.should  be_nil
        storage.servicenet.should == false
        storage.path.should       == 'backups'

        storage.storage_id.should be_nil
        storage.keep.should       be_nil
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Storage::CloudFiles.defaults do |s|
          s.username   = 'some_username'
          s.api_key    = 'some_api_key'
          s.auth_url   = 'some_auth_url'
          s.container  = 'some_container'
          s.servicenet = true
          s.path       = 'some_path'
          s.keep       = 15
        end
      end

      it 'should use pre-configured defaults' do
        storage = Backup::Storage::CloudFiles.new(model)

        storage.username.should   == 'some_username'
        storage.api_key.should    == 'some_api_key'
        storage.auth_url.should   == 'some_auth_url'
        storage.container.should  == 'some_container'
        storage.servicenet.should == true
        storage.path.should       == 'some_path'

        storage.storage_id.should be_nil
        storage.keep.should       == 15
      end

      it 'should override pre-configured defaults' do
        storage = Backup::Storage::CloudFiles.new(model) do |s|
          s.username   = 'new_username'
          s.api_key    = 'new_api_key'
          s.auth_url   = 'new_auth_url'
          s.container  = 'new_container'
          s.servicenet = false
          s.path       = 'new_path'
          s.keep       = 10
        end

        storage.username.should   == 'new_username'
        storage.api_key.should    == 'new_api_key'
        storage.auth_url.should   == 'new_auth_url'
        storage.container.should  == 'new_container'
        storage.servicenet.should == false
        storage.path.should       == 'new_path'

        storage.storage_id.should be_nil
        storage.keep.should       == 10
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#provider' do
    it 'should set the Fog provider' do
      storage.send(:provider).should == 'Rackspace'
    end
  end

  describe '#connection' do
    let(:connection) { mock }

    context 'when @servicenet is set to false' do
      it 'should create a new standard connection' do
        Fog::Storage.expects(:new).once.with(
          :provider             => 'Rackspace',
          :rackspace_username   => 'my_username',
          :rackspace_api_key    => 'my_api_key',
          :rackspace_auth_url   => 'lon.auth.api.rackspacecloud.com',
          :rackspace_servicenet => false
        ).returns(connection)
        storage.send(:connection).should == connection
      end
    end

    context 'when @servicenet is set to true' do
      before do
        storage.servicenet = true
      end

      it 'should create a new servicenet connection' do
        Fog::Storage.expects(:new).once.with(
          :provider             => 'Rackspace',
          :rackspace_username   => 'my_username',
          :rackspace_api_key    => 'my_api_key',
          :rackspace_auth_url   => 'lon.auth.api.rackspacecloud.com',
          :rackspace_servicenet => true
        ).returns(connection)
        storage.send(:connection).should == connection
      end
    end

    it 'should return an existing connection' do
      Fog::Storage.expects(:new).once.returns(connection)
      storage.send(:connection).should == connection
      storage.send(:connection).should == connection
    end

  end # describe '#connection'

end
