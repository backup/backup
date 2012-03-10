# encoding: utf-8

require File.expand_path('../../../../spec_helper.rb', __FILE__)

describe 'Backup::Configuration::Syncer::Cloud::CloudFiles' do
  before do
    Backup::Configuration::Syncer::Cloud::CloudFiles.defaults do |cf|
      cf.username   = 'my-username'
      cf.api_key    = 'my-api-key'
      cf.container  = 'my-container'
      cf.auth_url   = 'my-auth-url'
      cf.servicenet = true
    end
  end
  after { Backup::Configuration::Syncer::Cloud::CloudFiles.clear_defaults! }

  it 'should set the default cloud files configuration' do
    cf = Backup::Configuration::Syncer::Cloud::CloudFiles
    cf.username.should   == 'my-username'
    cf.api_key.should    == 'my-api-key'
    cf.container.should  == 'my-container'
    cf.auth_url.should   == 'my-auth-url'
    cf.servicenet.should == true
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Syncer::Cloud::CloudFiles.clear_defaults!

      cf = Backup::Configuration::Syncer::Cloud::CloudFiles
      cf.username.should   == nil
      cf.api_key.should    == nil
      cf.container.should  == nil
      cf.auth_url.should   == nil
      cf.servicenet.should == nil
    end
  end
end
