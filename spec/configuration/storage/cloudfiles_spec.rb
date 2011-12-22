# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Storage::CloudFiles do
  before do
    Backup::Configuration::Storage::CloudFiles.defaults do |cf|
      cf.username   = 'my_username'
      cf.api_key    = 'my_api_key'
      cf.container  = 'my_container'
      cf.path       = 'my_backups'
      cf.auth_url   = 'lon.auth.api.rackspacecloud.com'
      cf.servicenet = true
    end
  end

  it 'should set the default Cloud Files configuration' do
    cf = Backup::Configuration::Storage::CloudFiles
    cf.username.should   == 'my_username'
    cf.api_key.should    == 'my_api_key'
    cf.container.should  == 'my_container'
    cf.path.should       == 'my_backups'
    cf.auth_url.should   == 'lon.auth.api.rackspacecloud.com'
    cf.servicenet.should == true
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Storage::CloudFiles.clear_defaults!

      cf = Backup::Configuration::Storage::CloudFiles
      cf.username.should   == nil
      cf.api_key.should    == nil
      cf.container.should  == nil
      cf.path.should       == nil
      cf.auth_url.should   == nil
      cf.servicenet.should == nil
    end
  end
end
