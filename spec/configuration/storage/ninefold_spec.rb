# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Storage::Ninefold do
  before do
    Backup::Configuration::Storage::Ninefold.defaults do |nf|
      nf.storage_token  = 'my_storage_token'
      nf.storage_secret = 'my_storage_secret'
      nf.path           = 'my_backups'
    end
  end

  it 'should set the default Ninefold configuration' do
    ninefold = Backup::Configuration::Storage::Ninefold
    ninefold.storage_token.should  == 'my_storage_token'
    ninefold.storage_secret.should == 'my_storage_secret'
    ninefold.path.should           == 'my_backups'
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Storage::Ninefold.clear_defaults!

      ninefold = Backup::Configuration::Storage::Ninefold
      ninefold.storage_token.should  == nil
      ninefold.storage_secret.should == nil
      ninefold.path.should           == nil
    end
  end
end
