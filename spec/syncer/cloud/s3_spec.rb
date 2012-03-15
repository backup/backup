# encoding: utf-8
require File.expand_path('../../../spec_helper.rb', __FILE__)

describe 'Backup::Syncer::Cloud::S3' do
  let(:syncer) do
    Backup::Syncer::Cloud::S3.new do |s3|
      s3.access_key_id      = 'my_access_key_id'
      s3.secret_access_key  = 'my_secret_access_key'
      s3.bucket             = 'my_bucket'
      s3.region             = 'my_region'
    end
  end

  it 'should be a subclass of Syncer::Cloud::Base' do
    Backup::Syncer::Cloud::S3.
      superclass.should == Backup::Syncer::Cloud::Base
  end

  describe '#initialize' do
    after { Backup::Syncer::Cloud::S3.clear_defaults! }

    it 'should load pre-configured defaults through Syncer::Cloud::Base' do
      Backup::Syncer::Cloud::S3.any_instance.expects(:load_defaults!)
      syncer
    end

    it 'should strip any leading slash in path' do
      syncer = Backup::Syncer::Cloud::S3.new do |cloud|
        cloud.path = '/cleaned/path'
      end
      syncer.path.should == 'cleaned/path'
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        syncer.access_key_id.should     == 'my_access_key_id'
        syncer.secret_access_key.should == 'my_secret_access_key'
        syncer.bucket.should            == 'my_bucket'
        syncer.region.should            == 'my_region'
      end

      it 'should use default values if none are given' do
        syncer = Backup::Syncer::Cloud::S3.new

        # from Syncer::Base
        syncer.path.should    == 'backups'
        syncer.mirror.should  == false
        syncer.directories.should == []

        # from Syncer::Cloud::Base
        syncer.concurrency_type.should  == false
        syncer.concurrency_level.should == 2

        syncer.access_key_id.should     be_nil
        syncer.secret_access_key.should be_nil
        syncer.bucket.should            be_nil
        syncer.region.should            be_nil
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Syncer::Cloud::S3.defaults do |cloud|
          cloud.access_key_id      = 'default_access_key_id'
          cloud.secret_access_key  = 'default_secret_access_key'
          cloud.bucket             = 'default_bucket'
          cloud.region             = 'default_region'
        end
      end

      it 'should use pre-configured defaults' do
        syncer = Backup::Syncer::Cloud::S3.new

        # from Syncer::Base
        syncer.path.should    == 'backups'
        syncer.mirror.should  == false
        syncer.directories.should == []

        # from Syncer::Cloud::Base
        syncer.concurrency_type.should  == false
        syncer.concurrency_level.should == 2

        syncer.access_key_id.should     == 'default_access_key_id'
        syncer.secret_access_key.should == 'default_secret_access_key'
        syncer.bucket.should            == 'default_bucket'
        syncer.region.should            == 'default_region'
      end

      it 'should override pre-configured defaults' do
        syncer = Backup::Syncer::Cloud::S3.new do |cloud|
          cloud.path    = 'new_path'
          cloud.mirror  = 'new_mirror'
          cloud.concurrency_type    = 'new_concurrency_type'
          cloud.concurrency_level   = 'new_concurrency_level'

          cloud.access_key_id       = 'new_access_key_id'
          cloud.secret_access_key   = 'new_secret_access_key'
          cloud.bucket              = 'new_bucket'
          cloud.region              = 'new_region'
        end

        syncer.path.should    == 'new_path'
        syncer.mirror.should  == 'new_mirror'
        syncer.directories.should == []
        syncer.concurrency_type.should  == 'new_concurrency_type'
        syncer.concurrency_level.should == 'new_concurrency_level'

        syncer.access_key_id.should     == 'new_access_key_id'
        syncer.secret_access_key.should == 'new_secret_access_key'
        syncer.bucket.should            == 'new_bucket'
        syncer.region.should            == 'new_region'
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#connection' do
    let(:connection) { mock }

    before do
      Fog::Storage.expects(:new).once.with(
        :provider               => 'AWS',
        :aws_access_key_id      => 'my_access_key_id',
        :aws_secret_access_key  => 'my_secret_access_key',
        :region                 => 'my_region'
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
    let(:bucket)      { mock }

    before do
      syncer.stubs(:connection).returns(connection)
      connection.stubs(:directories).returns(directories)
    end

    context 'when the @bucket does not exist' do
      before do
        directories.expects(:get).once.with('my_bucket').returns(nil)
        directories.expects(:create).once.with(
          :key      => 'my_bucket',
          :location => 'my_region'
        ).returns(bucket)
      end

      it 'should create and re-use the bucket' do
        syncer.send(:repository_object).should == bucket
        syncer.instance_variable_get(:@repository_object).should == bucket
        syncer.send(:repository_object).should == bucket
      end
    end

    context 'when the @bucket does exist' do
      before do
        directories.expects(:get).once.with('my_bucket').returns(bucket)
        directories.expects(:create).never
      end

      it 'should retrieve and re-use the bucket' do
        syncer.send(:repository_object).should == bucket
        syncer.instance_variable_get(:@repository_object).should == bucket
        syncer.send(:repository_object).should == bucket
      end
    end
  end
end
