# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

##
# available S3 regions:
# eu-west-1, us-east-1, ap-southeast-1, us-west-1
describe Backup::Storage::S3 do
  let(:connection) { mock('Fog::Storage') }
  let(:s3) do
    Backup::Storage::S3.new do |s3|
      s3.access_key_id      = 'my_access_key_id'
      s3.secret_access_key  = 'my_secret_access_key'
      s3.region             = 'us-east-1'
      s3.bucket             = 'my-bucket'
      s3.path               = 'backups'
      s3.keep               = 20
    end
  end


  before do
    Backup::Configuration::Storage::S3.clear_defaults!
    Backup::Logger.stubs(:message)
  end

  it 'should have defined the configuration properly' do
    s3.access_key_id.should      == 'my_access_key_id'
    s3.secret_access_key.should  == 'my_secret_access_key'
    s3.region.should             == 'us-east-1'
    s3.bucket.should             == 'my-bucket'
    s3.keep.should               == 20
  end

  it 'should use the defaults if a particular attribute has not been defined' do
    Backup::Configuration::Storage::S3.defaults do |s3|
      s3.access_key_id = 'my_access_key_id'
      s3.region        = 'us-east-1'
      s3.keep          = 500
    end

    s3 = Backup::Storage::S3.new do |s3|
      s3.region = 'us-west-1'
      s3.path   = 'my/backups'
    end

    s3.access_key_id.should     == 'my_access_key_id' # not defined, uses default
    s3.secret_access_key.should == nil                # not defined, no default
    s3.region.should            == 'us-west-1'        # defined, overwrites default
    s3.bucket.should            == nil                # not defined, no default
    s3.path.should              == 'my/backups'       # overwritten from Backup::Storage::S3
    s3.keep.should              == 500                # comes from the default configuration
  end

  describe '#connection' do
    it 'should establish a connection to Amazon S3 using the provided credentials' do
      Fog::Storage.expects(:new).with({
        :provider               => 'AWS',
        :aws_access_key_id      => 'my_access_key_id',
        :aws_secret_access_key  => 'my_secret_access_key',
        :region                 => 'us-east-1'
      })

      s3.send(:connection)
    end
  end

  describe '#provider' do
    it 'should be AWS' do
      s3.provider == 'AWS'
    end
  end

  describe '#transfer!' do
    before do
      Fog::Storage.stubs(:new).returns(connection)
    end

    it 'should transfer the provided file to the bucket' do
      Backup::Model.new('blah', 'blah') {}
      file = mock("Backup::Storage::S3::File")
      File.expects(:open).with("#{File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER}")}.tar").returns(file)
      s3.expects(:remote_file).returns("#{ Backup::TIME }.#{ Backup::TRIGGER }.tar").twice
      connection.expects(:sync_clock)
      connection.expects(:put_object).with('my-bucket', "backups/myapp/#{ Backup::TIME }.#{ Backup::TRIGGER }.tar", file)
      s3.send(:transfer!)
    end
  end

  describe '#remove!' do
    before do
      Fog::Storage.stubs(:new).returns(connection)
    end

    it 'should remove the file from the bucket' do
      s3.expects(:remote_file).returns("#{ Backup::TIME }.#{ Backup::TRIGGER }.tar")
      connection.expects(:sync_clock)
      connection.expects(:delete_object).with('my-bucket', "backups/myapp/#{ Backup::TIME }.#{ Backup::TRIGGER }.tar")
      s3.send(:remove!)
    end
  end
  
  describe '#bucket_exists?' do
    before do
      Fog::Storage.stubs(:new).returns(connection)
      @directories = mock('directories')
      connection.expects(:directories).returns(@directories).at_least_once
    end
    
    it 'should return true if the bucket exists' do
      @directories.expects(:get).with('my-bucket').returns(mock('bucket'))
      s3.send(:bucket_exists?).should be_true
    end

    it 'should return true if the bucket exists' do
      @directories.expects(:get).with('my-bucket').returns(nil)
      s3.send(:bucket_exists?).should be_false
    end

    it 'should raise an exception if bucket exists but for someone else, with a nice err msg' do
      @directories.expects(:get).raises(Excon::Errors::Forbidden, "some s3 error msg")
      lambda{ s3.send(:bucket_exists?) }.should raise_exception(Exception, "An error occurred while trying to access this bucket.  It look like this bucket already exists but does so under a different account which you do not have access to." )
    end

    it 'should pass through a general exception an exception if bucket exists but for someone else, with a nice err msg' do
      @directories.expects(:get).raises(Exception, "some s3 error msg")
      lambda{ s3.send(:bucket_exists?) }.should raise_exception(Exception, "some s3 error msg" )
    end
  end

  describe '#create_bucket!' do
    before do
      Fog::Storage.stubs(:new).returns(connection)
      @directories = mock('directories')
      connection.expects(:directories).returns(@directories).at_least_once
    end
    
    it 'should create a bucket with the correct bucket name' do
      @directories.expects(:create).with do |args|
        args[:key].should == 'my-bucket'
      end
      s3.send(:create_bucket!)
    end

    it 'should create a bucket and default to it being private' do
      @directories.expects(:create).with do |args|
        args[:public].should be_false
      end
      s3.send(:create_bucket!)
    end

    it 'should raise an exception if bucket exists but for someone else, with a nice err msg' do
      @directories.expects(:create).raises(Excon::Errors::Forbidden, "some s3 error msg")
      lambda{ s3.send(:create_bucket!) }.should raise_exception(Exception, "An error occurred while trying to create this bucket.  It look like this bucket already exists but does so under a different account which you do not have access to." )
    end

    it 'should pass through a general exception an exception if bucket exists but for someone else, with a nice err msg' do
      @directories.expects(:create).raises(Exception, "some s3 error msg")
      lambda{ s3.send(:create_bucket!) }.should raise_exception(Exception, "some s3 error msg" )
    end
  end

  describe '#perform' do
    it 'should invoke a chain of helpers' do
      s3.expects(:bucket_exists?)
      s3.expects(:create_bucket!)
      s3.expects(:transfer!)
      s3.expects(:cycle!)
      s3.perform!
    end
    
    it 'should not create a bucket if bucket_exists? is true' do
      s3.expects(:bucket_exists?).returns(true)
      s3.expects(:transfer!)
      s3.expects(:cycle!)
      s3.perform!
    end

    it 'should create a bucket if bucket_exists? is false' do
      s3.expects(:bucket_exists?).returns(false)
      s3.expects(:create_bucket!)
      s3.expects(:transfer!)
      s3.expects(:cycle!)
      s3.perform!
    end
  end

end
