# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Syncer::RSync do
  before do
    Backup::Configuration::Syncer::RSync.defaults do |rsync|
      rsync.username  = 'my_username'
      rsync.password  = 'my_password'
      rsync.ip        = '123.45.678.90'
      rsync.port      = 22
      rsync.path      = '~/backups/'
      rsync.mirror    = true
      rsync.compress  = true
      rsync.additional_options = []
    end
  end

  it 'should set the default rsync configuration' do
    rsync = Backup::Configuration::Syncer::RSync
    rsync.username.should  == 'my_username'
    rsync.password.should  == 'my_password'
    rsync.ip.should        == '123.45.678.90'
    rsync.port.should      == 22
    rsync.path.should      == '~/backups/'
    rsync.mirror.should    == true
    rsync.compress.should  == true
    rsync.additional_options.should == []
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Syncer::RSync.clear_defaults!

      rsync = Backup::Configuration::Syncer::RSync
      rsync.username.should  == nil
      rsync.password.should  == nil
      rsync.ip.should        == nil
      rsync.port.should      == nil
      rsync.path.should      == nil
      rsync.mirror.should    == nil
      rsync.compress.should  == nil
      rsync.additional_options.should == nil
    end
  end
end
