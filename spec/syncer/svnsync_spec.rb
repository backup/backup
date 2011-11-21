# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Syncer::SVNSync do

  let(:svnsync) do
    Backup::Syncer::SVNSync.new do |svnsync|
      svnsync.username  = 'jimmy'
      svnsync.password  = 'secret'
      svnsync.host      = 'foo.com'
      svnsync.repo_path = '/my/repo'
    end
  end

  before do
    Backup::Configuration::Syncer::SVNSync.clear_defaults!
  end

  it 'should have defined the configuration properly' do
    svnsync.username.should  == 'jimmy'
    svnsync.password.should  == 'secret'
    svnsync.host.should      == 'foo.com'
    svnsync.repo_path.should == '/my/repo'
  end

  it 'should use the defaults if a particular attribute has not been defined' do
    Backup::Configuration::Syncer::SVNSync.defaults do |svnsync|
      svnsync.username  = 'my_default_username'
      svnsync.password  = 'my_default_password'
      svnsync.host      = 'my_default_host.com'
      svnsync.repo_path = '/my/default/path'
    end

    svnsync = Backup::Syncer::SVNSync.new do |svnsync|
      svnsync.password = "my_password"
      svnsync.protocol = "https"
      svnsync.port     = "443"
    end

    svnsync.username.should == 'my_default_username'
    svnsync.password.should == 'my_password'
    svnsync.host.should     == 'my_default_host.com'
    svnsync.repo_path       == '/my/default/path'
    svnsync.protocol.should == 'https'
    svnsync.port.should     == '443'
  end

  describe '#url' do
    it "gets calculated using protocol, host, port and path" do
      svnsync.url.should == "http://foo.com:80/my/repo"
    end
  end


end
