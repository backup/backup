# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Configuration::S3 do
  before do
    Backup::Configuration::S3.defaults do |s3|
      s3.access_key_id      = 'my_access_key_id'
      s3.secret_access_key  = 'my_secret_access_key'
      s3.region             = 'us-east-1'
    end
  end

  it 'should set the default S3 configuration' do
    Backup::Configuration::S3.access_key_id.should == 'my_access_key_id'
    Backup::Configuration::S3.secret_access_key.should == 'my_secret_access_key'
    Backup::Configuration::S3.region.should == 'us-east-1'
  end
end
