# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Syncer::CloudFiles do
  before do
    Backup::Configuration::Syncer::CloudFiles.defaults do |cf|
      cf.username   = 'my-username'
      cf.api_key    = 'my-api-key'
      cf.container  = 'my-container'
      cf.auth_url   = 'my-auth-url'
      cf.servicenet = true
      cf.path       = '/backups/'
      cf.mirror     = true
    end
  end
  after { Backup::Configuration::Syncer::CloudFiles.clear_defaults! }

  it 'should set the default cloud files configuration' do
    cf = Backup::Configuration::Syncer::CloudFiles
    cf.username.should   == 'my-username'
    cf.api_key.should    == 'my-api-key'
    cf.container.should  == 'my-container'
    cf.auth_url.should   == 'my-auth-url'
    cf.servicenet.should == true
    cf.path.should       == '/backups/'
    cf.mirror.should     == true
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Syncer::CloudFiles.clear_defaults!

      cf = Backup::Configuration::Syncer::CloudFiles
      cf.username.should   == nil
      cf.api_key.should    == nil
      cf.container.should  == nil
      cf.auth_url.should   == nil
      cf.servicenet.should == nil
      cf.path.should       == nil
      cf.mirror.should     == nil
    end
  end
end
