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
    Backup::Syncer::Cloud::CloudFiles.
      superclass.should == Backup::Syncer::Cloud::Base
  end

  describe '#initialize' do
    after { Backup::Syncer::Cloud::CloudFiles.clear_defaults! }

    it 'should load pre-configured defaults through Syncer::Cloud::Base' do
      Backup::Syncer::Cloud::CloudFiles.any_instance.expects(:load_defaults!)
      syncer
    end

    it 'should strip any leading slash in path' do
      syncer = Backup::Syncer::Cloud::CloudFiles.new do |cloud|
        cloud.path = '/cleaned/path'
      end
      syncer.path.should == 'cleaned/path'
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        syncer.api_key.should     == 'my_api_key'
        syncer.username.should    == 'my_username'
        syncer.container.should   == 'my_container'
        syncer.auth_url.should    == 'my_auth_url'
        syncer.servicenet.should  == true
      end

      it 'should use default values if none are given' do
        syncer = Backup::Syncer::Cloud::CloudFiles.new

        # from Syncer::Base
        syncer.path.should    == 'backups'
        syncer.mirror.should  == false
        syncer.directories.should == []

        # from Syncer::Cloud::Base
        syncer.concurrency_type.should  == false
        syncer.concurrency_level.should == 2

        syncer.api_key.should     == nil
        syncer.username.should    == nil
        syncer.container.should   == nil
        syncer.auth_url.should    == nil
        syncer.servicenet.should  == false
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Syncer::Cloud::CloudFiles.defaults do |cloud|
          cloud.api_key      = 'default_api_key'
          cloud.username     = 'default_username'
          cloud.container    = 'default_container'
          cloud.auth_url     = 'default_auth_url'
          cloud.servicenet   = 'default_servicenet'
        end
      end

      it 'should use pre-configured defaults' do
        syncer = Backup::Syncer::Cloud::CloudFiles.new

        # from Syncer::Base
        syncer.path.should    == 'backups'
        syncer.mirror.should  == false
        syncer.directories.should == []

        # from Syncer::Cloud::Base
        syncer.concurrency_type.should  == false
        syncer.concurrency_level.should == 2

        syncer.api_key.should      == 'default_api_key'
        syncer.username.should     == 'default_username'
        syncer.container.should    == 'default_container'
        syncer.auth_url.should     == 'default_auth_url'
        syncer.servicenet.should   == 'default_servicenet'
      end

      it 'should override pre-configured defaults' do
        syncer = Backup::Syncer::Cloud::CloudFiles.new do |cloud|
          cloud.path    = 'new_path'
          cloud.mirror  = 'new_mirror'
          cloud.concurrency_type    = 'new_concurrency_type'
          cloud.concurrency_level   = 'new_concurrency_level'

          cloud.api_key      = 'new_api_key'
          cloud.username     = 'new_username'
          cloud.container    = 'new_container'
          cloud.auth_url     = 'new_auth_url'
          cloud.servicenet   = 'new_servicenet'
        end

        syncer.path.should    == 'new_path'
        syncer.mirror.should  == 'new_mirror'
        syncer.directories.should == []
        syncer.concurrency_type.should  == 'new_concurrency_type'
        syncer.concurrency_level.should == 'new_concurrency_level'

        syncer.api_key.should      == 'new_api_key'
        syncer.username.should     == 'new_username'
        syncer.container.should    == 'new_container'
        syncer.auth_url.should     == 'new_auth_url'
        syncer.servicenet.should   == 'new_servicenet'
      end
    end # context 'when pre-configured defaults have been set'
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
