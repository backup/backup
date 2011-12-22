# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Storage::SFTP do
  before do
    Backup::Configuration::Storage::SFTP.defaults do |sftp|
      sftp.username  = 'my_username'
      sftp.password  = 'my_password'
      sftp.ip        = '123.45.678.90'
      sftp.port      = 22
      sftp.path      = 'my_backups'
      sftp.keep      = 20
    end
  end

  it 'should set the default sftp configuration' do
    sftp = Backup::Configuration::Storage::SFTP
    sftp.username.should == 'my_username'
    sftp.password.should == 'my_password'
    sftp.ip.should       == '123.45.678.90'
    sftp.port.should     == 22
    sftp.path.should     == 'my_backups'
    sftp.keep.should     == 20
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Storage::SFTP.clear_defaults!

      sftp = Backup::Configuration::Storage::SFTP
      sftp.username.should == nil
      sftp.password.should == nil
      sftp.ip.should       == nil
      sftp.port.should     == nil
      sftp.path.should     == nil
      sftp.keep.should     == nil
    end
  end
end
