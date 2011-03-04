# encoding: utf-8

require File.dirname(__FILE__) + '/../../spec_helper'

describe Backup::Configuration::Storage::SCP do
  before do
    Backup::Configuration::Storage::SCP.defaults do |scp|
      scp.username  = 'my_username'
      scp.password  = 'my_password'
      scp.ip        = '123.45.678.90'
      scp.port      = 21
      scp.path      = '~/backups/'
      scp.keep      = 20
    end
  end

  it 'should set the default scp configuration' do
    scp = Backup::Configuration::Storage::SCP
    scp.username.should == 'my_username'
    scp.password.should == 'my_password'
    scp.ip.should       == '123.45.678.90'
    scp.port.should     == 21
    scp.path.should     == '~/backups/'
    scp.keep.should     == 20
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Storage::SCP.clear_defaults!

      scp = Backup::Configuration::Storage::SCP
      scp.username.should == nil
      scp.password.should == nil
      scp.ip.should       == nil
      scp.port.should     == nil
      scp.path.should     == nil
      scp.keep.should     == nil
    end
  end
end
