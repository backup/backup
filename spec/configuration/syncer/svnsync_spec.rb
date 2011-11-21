# encoding: utf-8

require File.dirname(__FILE__) + '/../../spec_helper'

describe Backup::Configuration::Syncer::SVNSync do
  before do
    Backup::Configuration::Syncer::SVNSync.defaults do |svnsync|
      svnsync.protocol  = 'http'
      svnsync.username  = 'my_username'
      svnsync.password  = 'my_password'
      svnsync.host      = '123.45.678.90'
      svnsync.port      = 88
      svnsync.repo_path = '/my/repo/'
      svnsync.path      = '~/backups/'
    end
  end

  it 'should set the default svnsync configuration' do
    svnsync = Backup::Configuration::Syncer::SVNSync
    svnsync.protocol.should  == 'http'
    svnsync.username.should  == 'my_username'
    svnsync.password.should  == 'my_password'
    svnsync.host.should      == '123.45.678.90'
    svnsync.port.should      == 88
    svnsync.repo_path.should == '/my/repo/'
    svnsync.path.should      == '~/backups/'
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Syncer::SVNSync.clear_defaults!

      svnsync = Backup::Configuration::Syncer::SVNSync
      svnsync.protocol.should  == nil
      svnsync.username.should  == nil
      svnsync.password.should  == nil
      svnsync.host.should      == nil
      svnsync.port.should      == nil
      svnsync.repo_path.should == nil
      svnsync.path.should      == nil
    end
  end
end
