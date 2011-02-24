# encoding: utf-8

require File.dirname(__FILE__) + '/../../spec_helper'

describe Backup::Configuration::Storage::S3 do
  before do
    Backup::Configuration::Storage::S3.defaults do |s3|
      s3.access_key_id      = 'my_access_key_id'
      s3.secret_access_key  = 'my_secret_access_key'
      s3.region             = 'us-east-1'
      s3.bucket             = 'my-bucket'
    end
  end

  it 'should set the default S3 configuration' do
    s3 = Backup::Configuration::Storage::S3
    s3.access_key_id.should     == 'my_access_key_id'
    s3.secret_access_key.should == 'my_secret_access_key'
    s3.region.should            == 'us-east-1'
    s3.bucket.should            == 'my-bucket'
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Storage::S3.clear_defaults!

      s3 = Backup::Configuration::Storage::S3
      s3.access_key_id.should     == nil
      s3.secret_access_key.should == nil
      s3.region.should            == nil
      s3.bucket.should            == nil
    end
  end
end
