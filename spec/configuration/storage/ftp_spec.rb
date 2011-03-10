# encoding: utf-8

require File.dirname(__FILE__) + '/../../spec_helper'

describe Backup::Configuration::Storage::FTP do
  before do
    Backup::Configuration::Storage::FTP.defaults do |ftp|
      ftp.username  = 'my_username'
      ftp.password  = 'my_password'
      ftp.ip        = '123.45.678.90'
      ftp.port      = 21
      ftp.path      = 'my_backups'
      ftp.keep      = 20
    end
  end

  it 'should set the default ftp configuration' do
    ftp = Backup::Configuration::Storage::FTP
    ftp.username.should == 'my_username'
    ftp.password.should == 'my_password'
    ftp.ip.should       == '123.45.678.90'
    ftp.port.should     == 21
    ftp.path.should     == 'my_backups'
    ftp.keep.should     == 20
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Storage::FTP.clear_defaults!

      ftp = Backup::Configuration::Storage::FTP
      ftp.username.should == nil
      ftp.password.should == nil
      ftp.ip.should       == nil
      ftp.port.should     == nil
      ftp.path.should     == nil
      ftp.keep.should     == nil
    end
  end
end
