# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Compressor::Gzip do

  context "when no block is provided" do
    let(:encryptor) { Backup::Encryptor::OpenSSL.new }

    it do
      encryptor.password.should == nil
    end

    it do
      encryptor.send(:base64).should == []
    end

    it do
      encryptor.send(:salt).should == []
    end

    it do
      encryptor.send(:options).should == "aes-256-cbc"
    end
  end

  context "when a block is provided" do
    let(:encryptor) do
      Backup::Encryptor::OpenSSL.new do |e|
        e.password = "my_secret_password"
        e.salt     = true
        e.base64   = true
      end
    end

    it do
      encryptor.password.should == "my_secret_password"
    end

    it do
      encryptor.send(:salt).should == ['-salt']
    end

    it do
      encryptor.send(:base64).should == ['-a']
    end

    it do
      encryptor.send(:options).should == "aes-256-cbc -a -salt"
    end
  end

  describe '#perform!' do
    let(:encryptor) { Backup::Encryptor::OpenSSL.new }
    before do
      Backup::Model.new('blah', 'blah') {}
    end

    it do
      encryptor = Backup::Encryptor::OpenSSL.new
      encryptor.expects(:utility).returns(:openssl)
      encryptor.expects(:run).with("openssl aes-256-cbc -in '#{ File.join(Backup::TMP_PATH, "#{Backup::TIME}.#{Backup::TRIGGER}.tar") }' -out '#{ File.join(Backup::TMP_PATH, "#{Backup::TIME}.#{Backup::TRIGGER}.tar.enc") }' -k ''")
      encryptor.perform!
    end

    it do
      encryptor = Backup::Encryptor::OpenSSL.new do |e|
        e.password = "my_secret_password"
        e.salt     = true
        e.base64   = true
      end
      encryptor.stubs(:utility).returns(:openssl)
      encryptor.expects(:run).with("openssl aes-256-cbc -a -salt -in '#{ File.join(Backup::TMP_PATH, "#{Backup::TIME}.#{Backup::TRIGGER}.tar") }' -out '#{ File.join(Backup::TMP_PATH, "#{Backup::TIME}.#{Backup::TRIGGER}.tar.enc") }' -k 'my_secret_password'")
      encryptor.perform!
    end

    it 'should append the .enc extension after the encryption' do
      encryptor.stubs(:run)
      Backup::Model.extension.should == 'tar'
      encryptor.perform!
      Backup::Model.extension.should == 'tar.enc'
    end

    it do
      encryptor.expects(:utility).with(:openssl)
      encryptor.stubs(:run)
      encryptor.perform!
    end
  end
end
