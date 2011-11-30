# encoding: utf-8

require File.dirname(__FILE__) + '/../../spec_helper'

describe Backup::Configuration::Encryptor::OpenSSL do
  before do
    Backup::Configuration::Encryptor::OpenSSL.defaults do |encryptor|
      encryptor.password = 'my_password'
      encryptor.password_file = nil
      encryptor.base64   = true
      encryptor.salt     = true
    end
  end

  it 'should set the default encryptor configuration' do
    encryptor = Backup::Configuration::Encryptor::OpenSSL
    encryptor.password.should == 'my_password'
    encryptor.password_file.should == nil
    encryptor.base64.should   == true
    encryptor.salt.should     == true
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Encryptor::OpenSSL.clear_defaults!

      encryptor = Backup::Configuration::Encryptor::OpenSSL
      encryptor.password.should == nil
      encryptor.password_file.should == nil
      encryptor.base64.should   == nil
      encryptor.salt.should     == nil
    end
  end
end
