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
    Backup::Syncer::Cloud::S3.superclass.
        should == Backup::Syncer::Cloud::Base
  end

  describe '#initialize' do
    it 'should have defined the configuration properly' do
      syncer.access_key_id.should     == 'my_access_key_id'
      syncer.secret_access_key.should == 'my_secret_access_key'
      syncer.bucket.should            == 'my_bucket'
      syncer.region.should            == 'my_region'
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
        syncer = Backup::Syncer::Cloud::S3.new
        syncer.access_key_id.should     == nil
        syncer.secret_access_key.should == nil
        syncer.bucket.should            == nil
        syncer.region.should            == nil
      end
    end

    context 'when setting configuration defaults' do
      after { Backup::Configuration::Syncer::Cloud::S3.clear_defaults! }

      it 'should use the configured defaults' do
        Backup::Configuration::Syncer::Cloud::S3.defaults do |s3|
          s3.access_key_id      = 'default_access_key_id'
          s3.secret_access_key  = 'default_secret_access_key'
          s3.bucket             = 'default_bucket'
          s3.region             = 'default_region'
        end
        syncer = Backup::Syncer::Cloud::S3.new
        syncer.access_key_id.should     == 'default_access_key_id'
        syncer.secret_access_key.should == 'default_secret_access_key'
        syncer.bucket.should            == 'default_bucket'
        syncer.region.should            == 'default_region'
      end

      it 'should override the configured defaults' do
        Backup::Configuration::Syncer::Cloud::S3.defaults do |s3|
          s3.access_key_id      = 'old_access_key_id'
          s3.secret_access_key  = 'old_secret_access_key'
          s3.bucket             = 'old_bucket'
          s3.region             = 'old_region'
        end
        syncer = Backup::Syncer::Cloud::S3.new do |s3|
          s3.access_key_id      = 'new_access_key_id'
          s3.secret_access_key  = 'new_secret_access_key'
          s3.bucket             = 'new_bucket'
          s3.region             = 'new_region'
        end

        syncer.access_key_id.should     == 'new_access_key_id'
        syncer.secret_access_key.should == 'new_secret_access_key'
        syncer.bucket.should            == 'new_bucket'
        syncer.region.should            == 'new_region'
      end
    end # context 'when setting configuration defaults'
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
