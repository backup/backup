# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Encryptor::GPG do
  before do
    Backup::Configuration::Encryptor::GPG.defaults do |encryptor|
      encryptor.key = 'my_key'
    end
  end

  it 'should set the default encryptor configuration' do
    encryptor = Backup::Configuration::Encryptor::GPG
    encryptor.key.should == 'my_key'
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Encryptor::GPG.clear_defaults!

      encryptor = Backup::Configuration::Encryptor::GPG
      encryptor.key.should == nil
    end
  end
end
