# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Storage::RSync do
  before do
    Backup::Configuration::Storage::RSync.defaults do |rsync|
      rsync.username  = 'my_username'
      rsync.password  = 'my_password'
      rsync.ip        = '123.45.678.90'
      rsync.port      = 21
      rsync.path      = 'my_backups'
      rsync.local     = true
    end
  end

  it 'should set the default rsync configuration' do
    rsync = Backup::Configuration::Storage::RSync
    rsync.username.should == 'my_username'
    rsync.password.should == 'my_password'
    rsync.ip.should       == '123.45.678.90'
    rsync.port.should     == 21
    rsync.path.should     == 'my_backups'
    rsync.local.should    == true
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Storage::RSync.clear_defaults!

      rsync = Backup::Configuration::Storage::RSync
      rsync.username.should == nil
      rsync.password.should == nil
      rsync.ip.should       == nil
      rsync.port.should     == nil
      rsync.path.should     == nil
      rsync.local.should    == nil
    end
  end
end
