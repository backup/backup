# encoding: utf-8

require File.dirname(__FILE__) + '/../../spec_helper'

describe Backup::Configuration::Storage::Dropbox do
  before do
    Backup::Configuration::Storage::Dropbox.defaults do |db|
      db.api_key     = 'my_api_key'
      db.api_secret  = 'my_secret'
      db.path        = 'my_backups'
      db.keep        = 20
      db.timeout     = 500
    end
  end

  it 'should set the default Dropbox configuration' do
    db = Backup::Configuration::Storage::Dropbox
    db.api_key.should     == 'my_api_key'
    db.api_secret.should  == 'my_secret'
    db.path.should        == 'my_backups'
    db.keep.should        == 20
    db.timeout.should     == 500
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Storage::Dropbox.clear_defaults!

      db = Backup::Configuration::Storage::Dropbox
      db.api_key.should     == nil
      db.api_secret.should  == nil
      db.path.should        == nil
      db.keep.should        == nil
      db.timeout.should     == nil
    end
  end
end
