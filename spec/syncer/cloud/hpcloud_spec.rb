# encoding: utf-8
require File.expand_path('../../../spec_helper.rb', __FILE__)

describe 'Backup::Syncer::Cloud::HPCloud' do
  let(:syncer) do
    Backup::Syncer::Cloud::HPCloud.new do |hpcloud|
      hpcloud.hp_access_key    = 'my_access_key'
      hpcloud.hp_secret_key    = 'my_secret_key'
      hpcloud.hp_auth_uri      = 'my_auth_uri'
      hpcloud.hp_tenant_id     = 'my_tenant_id'
      hpcloud.hp_avl_zone      = 'my_avl_zone'
      hpcloud.container        = 'my_container'
    end
  end

  it 'should be a subclass of Syncer::Cloud::Base' do
    Backup::Syncer::Cloud::HPCloud.
      superclass.should == Backup::Syncer::Cloud::Base
  end

  describe '#initialize' do
    after { Backup::Syncer::Cloud::HPCloud.clear_defaults! }

    it 'should load pre-configured defaults through Syncer::Cloud::Base' do
      Backup::Syncer::Cloud::HPCloud.any_instance.expects(:load_defaults!)
      syncer
    end

    it 'should strip any leading slash in path' do
      syncer = Backup::Syncer::Cloud::HPCloud.new do |cloud|
        cloud.path = '/cleaned/path'
      end
      syncer.path.should == 'cleaned/path'
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        syncer.hp_access_key.should     == 'my_access_key'
        syncer.hp_secret_key.should     == 'my_secret_key'
        syncer.hp_auth_uri.should       == 'my_auth_uri'
        syncer.hp_tenant_id.should      == 'my_tenant_id'
        syncer.hp_avl_zone.should       == 'my_avl_zone'
        syncer.container.should         == 'my_container'
      end

      it 'should use default values if none are given' do
        syncer = Backup::Syncer::Cloud::HPCloud.new

        # from Syncer::Base
        syncer.path.should    == 'backups'
        syncer.mirror.should  == false
        syncer.directories.should == []

        # from Syncer::Cloud::Base
        syncer.concurrency_type.should  == false
        syncer.concurrency_level.should == 2

        syncer.hp_access_key.should     be_nil
        syncer.hp_secret_key.should     be_nil
        syncer.hp_auth_uri.should       be_nil
        syncer.hp_tenant_id.should      be_nil
        syncer.hp_avl_zone.should       be_nil
        syncer.container.should         be_nil
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Syncer::Cloud::HPCloud.defaults do |cloud|
          cloud.hp_access_key    = 'default_access_key'
          cloud.hp_secret_key    = 'default_secret_key'
          cloud.hp_auth_uri      = 'default_auth_uri'
          cloud.hp_tenant_id     = 'default_tenant_id'
          cloud.hp_avl_zone      = 'default_avl_zone'
          cloud.container        = 'default_container'
        end
      end

      it 'should use pre-configured defaults' do
        syncer = Backup::Syncer::Cloud::HPCloud.new

        # from Syncer::Base
        syncer.path.should    == 'backups'
        syncer.mirror.should  == false
        syncer.directories.should == []

        # from Syncer::Cloud::Base
        syncer.concurrency_type.should  == false
        syncer.concurrency_level.should == 2

        syncer.hp_access_key.should     == 'default_access_key'
        syncer.hp_secret_key.should     == 'default_secret_key'
        syncer.hp_auth_uri.should       == 'default_auth_uri'
        syncer.hp_tenant_id.should      == 'default_tenant_id'
        syncer.hp_avl_zone.should       == 'default_avl_zone'
        syncer.container.should         == 'default_container'
      end

      it 'should override pre-configured defaults' do
        syncer = Backup::Syncer::Cloud::HPCloud.new do |cloud|
          cloud.path    = 'new_path'
          cloud.mirror  = 'new_mirror'
          cloud.concurrency_type    = 'new_concurrency_type'
          cloud.concurrency_level   = 'new_concurrency_level'

          cloud.hp_access_key    = 'new_access_key'
          cloud.hp_secret_key    = 'new_secret_key'
          cloud.hp_auth_uri      = 'new_auth_uri'
          cloud.hp_tenant_id     = 'new_tenant_id'
          cloud.hp_avl_zone      = 'new_avl_zone'
          cloud.container        = 'new_container'
        end

        syncer.path.should    == 'new_path'
        syncer.mirror.should  == 'new_mirror'
        syncer.directories.should == []
        syncer.concurrency_type.should  == 'new_concurrency_type'
        syncer.concurrency_level.should == 'new_concurrency_level'

        syncer.hp_access_key.should     == 'new_access_key'
        syncer.hp_secret_key.should     == 'new_secret_key'
        syncer.hp_auth_uri.should       == 'new_auth_uri'
        syncer.hp_tenant_id.should      == 'new_tenant_id'
        syncer.hp_avl_zone.should       == 'new_avl_zone'
        syncer.container.should         == 'new_container'
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#connection' do
    let(:connection) { mock }

    before do
      Fog::Storage.expects(:new).once.with(
        :provider       => 'HP',
        :hp_access_key  => 'my_access_key',
        :hp_secret_key  => 'my_secret_key',
        :hp_auth_uri    => 'my_auth_uri',
        :hp_tenant_id   => 'my_tenant_id',
        :hp_avl_zone    => 'my_avl_zone'
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
    let(:container)      { mock }

    before do
      syncer.stubs(:connection).returns(connection)
      connection.stubs(:directories).returns(directories)
    end

    context 'when the @container does not exist' do
      before do
        directories.expects(:get).once.with('my_container').returns(nil)
        directories.expects(:create).once.with(
          :key      => 'my_container'
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
