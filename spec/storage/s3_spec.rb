# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

##
# available S3 regions:
# eu-west-1, us-east-1, ap-southeast-1, us-west-1
describe Backup::Storage::S3 do

  let(:s3) do
    Backup::Storage::S3.new do |s3|
      s3.access_key_id      = 'my_access_key_id'
      s3.secret_access_key  = 'my_secret_access_key'
      s3.region             = 'us-east-1'
      s3.bucket             = 'my-bucket'
    end
  end

  before do
    Backup::Configuration::S3.clear_defaults!
  end

  it 'should have defined the configuration properly' do
    s3.access_key_id.should      == 'my_access_key_id'
    s3.secret_access_key.should  == 'my_secret_access_key'
    s3.region.should             == 'us-east-1'
    s3.bucket.should             == 'my-bucket'
  end

  it 'should use the defaults if a particular attribute has not been defined' do
    Backup::Configuration::S3.defaults do |s3|
      s3.access_key_id      = 'my_access_key_id'
      s3.region             = 'us-east-1'
    end

    s3 = Backup::Storage::S3.new do |s3|
      s3.region = 'us-west-1'
    end

    s3.access_key_id.should     == 'my_access_key_id' # not defined, uses default
    s3.secret_access_key.should == nil                # not defined, no default
    s3.region.should            == 'us-west-1'        # defined, overwrites default
    s3.bucket.should            == nil                # not defined, no default
  end

  describe '#connection' do
    it 'should establish a connection to Amazon S3 using the provided credentials' do
      Fog::Storage.expects(:new).with({
        :provider               => 'AWS',
        :aws_access_key_id      => 'my_access_key_id',
        :aws_secret_access_key  => 'my_secret_access_key',
        :region                 => 'us-east-1'
      })

      s3.connection
    end
  end

  describe '#provider' do
    it 'should be AWS' do
      s3.provider == 'AWS'
    end
  end

  describe '#transfer!' do
    let(:connection) { mock('Fog::Storage') }
    before do
      Fog::Storage.stubs(:new).returns(connection)
    end

    it 'should transfer the provided file to the bucket' do
      file = mock("Backup::Storage::File")
      s3.expects(:file).returns(file)
      s3.expects(:remote_file).returns("#{ Backup::TIME }.#{ Backup::TRIGGER }.tar")
      connection.expects(:put_object).with('my-bucket', "backup/myapp/#{ Backup::TIME }.#{ Backup::TRIGGER }.tar", file)
      s3.transferred?.should == false
      s3.transfer!
      s3.transferred?.should == true
    end
  end

  describe '#remove!' do
    let(:connection) { mock('Fog::Storage') }
    before do
      Fog::Storage.stubs(:new).returns(connection)
    end

    it 'should remove the file from the bucket' do
      s3.expects(:remote_file).returns("#{ Backup::TIME }.#{ Backup::TRIGGER }.tar")
      connection.expects(:delete_object).with('my-bucket', "backup/myapp/#{ Backup::TIME }.#{ Backup::TRIGGER }.tar")
      s3.remove!
    end
  end

  describe '#perform' do
    it 'should invoke create_bucket! and transfer!' do
      s3.expects(:transfer!)
      s3.perform!
    end
  end
end
