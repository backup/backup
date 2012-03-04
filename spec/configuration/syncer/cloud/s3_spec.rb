# encoding: utf-8

require File.expand_path('../../../../spec_helper.rb', __FILE__)

describe 'Backup::Configuration::Syncer::S3' do
  it 'should be a subclass of Syncer::Cloud::Base' do
    s3 = Backup::Configuration::Syncer::Cloud::S3
    s3.superclass.should == Backup::Configuration::Syncer::Cloud::Base
  end

  before do
    Backup::Configuration::Syncer::Cloud::S3.defaults do |s3|
      s3.access_key_id       = 'my_access_key_id'
      s3.secret_access_key   = 'my_secret_access_key'
      s3.bucket              = 'my-bucket'
    end
  end
  after { Backup::Configuration::Syncer::Cloud::S3.clear_defaults! }

  it 'should set the default s3 configuration' do
    s3 = Backup::Configuration::Syncer::Cloud::S3
    s3.access_key_id.should       == 'my_access_key_id'
    s3.secret_access_key.should   == 'my_secret_access_key'
    s3.bucket.should              == 'my-bucket'
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Syncer::Cloud::S3.clear_defaults!

      s3 = Backup::Configuration::Syncer::Cloud::S3
      s3.access_key_id.should       == nil
      s3.secret_access_key.should   == nil
      s3.bucket.should              == nil
    end
  end
end
