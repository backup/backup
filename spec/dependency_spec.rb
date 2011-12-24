# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

describe Backup::Dependency do
  before do
    Backup::Dependency.stubs(:all).returns(
      'net-sftp' => {
        :require => 'net/sftp',
        :version => '~> 2.0.5',
        :for     => 'SFTP Protocol (SFTP Storage)'
    })
  end

  describe ".load" do
    it "should load and require given dependency" do
      Backup::Dependency.expects(:gem).with("net-sftp", "~> 2.0.5")
      Backup::Dependency.expects(:require).with("net/sftp")
      Backup::Dependency.load("net-sftp")
    end

    context "on a missing dependency" do
      before do
        Backup::Dependency.stubs(:gem).raises(LoadError)
      end

      it "should display error message" do
        Backup::Logger.expects(:error).with do |exception|
          exception.message.should == "Dependency::LoadError: Dependency missing
  Dependency required for:
  SFTP Protocol (SFTP Storage)
  To install the gem, issue the following command:
  > gem install net-sftp -v '~> 2.0.5'
  Please try again after installing the missing dependency."
        end

        expect do
          Backup::Dependency.load("net-sftp")
        end.to raise_error(SystemExit)
      end

      it "should exit with status code 1" do
        expect do
          Backup::Dependency.load("net-sftp")
        end.to raise_error { |exit| exit.status.should be(1) }
      end
    end
  end
end
