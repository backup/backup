# encoding: utf-8
require File.expand_path('../../../spec_helper.rb', __FILE__)

describe 'Backup::Syncer::Cloud::CloudFiles' do
  let(:syncer) do
    Backup::Syncer::Cloud::CloudFiles.new do |cf|
      cf.api_key      = 'my_api_key'
      cf.username     = 'my_username'
      cf.container    = 'my_container'
      cf.auth_url     = 'my_auth_url'
      cf.servicenet   = true
    end
  end

  it 'should be a subclass of Syncer::Cloud::Base' do
    Backup::Syncer::Cloud::CloudFiles.superclass.
        should == Backup::Syncer::Cloud::Base
  end

  describe '#initialize' do
    it 'should have defined the configuration properly' do
      syncer.api_key.should     == 'my_api_key'
      syncer.username.should    == 'my_username'
      syncer.container.should   == 'my_container'
      syncer.auth_url.should    == 'my_auth_url'
      syncer.servicenet.should  == true
    end

    it 'should inherit default values from superclasses' do
      # Syncer::Cloud::Base
      syncer.concurrency_type.should  == false
      syncer.concurrency_level.should == 2

      # Syncer::Base
      syncer.path.should        == 'backups'
      syncer.mirror.should      == false
      syncer.directories.should == []
    end

    context 'when options are not set' do
      it 'should use default values' do
        syncer = Backup::Syncer::Cloud::CloudFiles.new
        syncer.api_key.should     == nil
        syncer.username.should    == nil
        syncer.container.should   == nil
        syncer.auth_url.should    == nil
        syncer.servicenet.should  == nil
      end
    end

    context 'when setting configuration defaults' do
      after { Backup::Configuration::Syncer::Cloud::CloudFiles.clear_defaults! }

      it 'should use the configured defaults' do
        Backup::Configuration::Syncer::Cloud::CloudFiles.defaults do |cf|
          cf.api_key      = 'default_api_key'
          cf.username     = 'default_username'
          cf.container    = 'default_container'
          cf.auth_url     = 'default_auth_url'
          cf.servicenet   = 'default_servicenet'
        end
        syncer = Backup::Syncer::Cloud::CloudFiles.new
        syncer.api_key.should      == 'default_api_key'
        syncer.username.should     == 'default_username'
        syncer.container.should    == 'default_container'
        syncer.auth_url.should     == 'default_auth_url'
        syncer.servicenet.should   == 'default_servicenet'
      end

      it 'should override the configured defaults' do
        Backup::Configuration::Syncer::Cloud::CloudFiles.defaults do |cf|
          cf.api_key      = 'old_api_key'
          cf.username     = 'old_username'
          cf.container    = 'old_container'
          cf.auth_url     = 'old_auth_url'
          cf.servicenet   = 'old_servicenet'
        end
        syncer = Backup::Syncer::Cloud::CloudFiles.new do |cf|
          cf.api_key      = 'new_api_key'
          cf.username     = 'new_username'
          cf.container    = 'new_container'
          cf.auth_url     = 'new_auth_url'
          cf.servicenet   = 'new_servicenet'
        end

        syncer.api_key.should      == 'new_api_key'
        syncer.username.should     == 'new_username'
        syncer.container.should    == 'new_container'
        syncer.auth_url.should     == 'new_auth_url'
        syncer.servicenet.should   == 'new_servicenet'
      end
    end # context 'when setting configuration defaults'
  end # describe '#initialize'

  describe '#connection' do
    let(:connection) { mock }

    before do
      Fog::Storage.expects(:new).once.with(
        :provider             => 'Rackspace',
        :rackspace_username   => 'my_username',
        :rackspace_api_key    => 'my_api_key',
        :rackspace_auth_url   => 'my_auth_url',
        :rackspace_servicenet => true
      ).returns(connection)
    end

    it 'should establish and re-use the connection' do
      syncer.send(:connection).should == connection
      syncer.instance_variable_get(:@connection).should == connection
      syncer.send(:connection).should == connection
    end
  end

  describe '#repository_object' do
    let(:connection)  { mock }
    let(:directories) { mock }
    let(:container)   { mock }

    before do
      syncer.stubs(:connection).returns(connection)
      connection.stubs(:directories).returns(directories)
    end

    context 'when the @container does not exist' do
      before do
        directories.expects(:get).once.with('my_container').returns(nil)
        directories.expects(:create).once.with(
          :key => 'my_container'
        ).returns(container)
      end

      it 'should create and re-use the container' do
        syncer.send(:repository_object).should == container
        syncer.instance_variable_get(:@repository_object).should == container
        syncer.send(:repository_object).should == container
      end
    end

    context 'when the @container does exist' do
      before do
        directories.expects(:get).once.with('my_container').returns(container)
        directories.expects(:create).never
      end

      it 'should retrieve and re-use the container' do
        syncer.send(:repository_object).should == container
        syncer.instance_variable_get(:@repository_object).should == container
        syncer.send(:repository_object).should == container
      end
    end
  end
end
