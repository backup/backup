# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Encryptor::OpenSSL do

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
      encryptor.send(:pass).should == ["-k ''"]
    end
    
    it do
      encryptor.send(:options).should == "aes-256-cbc -k ''"
    end
  end

  context "when a block is provided" do
    
    context "with a password" do    
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
        encryptor.send(:base64).should == ['-base64']
      end
      
      it do
        encryptor.send(:pass).should == ["-k 'my_secret_password'"]
      end
      
      it do
        encryptor.send(:options).should == "aes-256-cbc -base64 -salt -k 'my_secret_password'"
      end
    end
    
    context "with a password file" do    
      let(:encryptor) do
        Backup::Encryptor::OpenSSL.new do |e|
          e.password_file = "/path/to/password/file"
          e.salt     = true
          e.base64   = true
        end
      end

      it do
        encryptor.password.should == nil
      end
      
      it do
        encryptor.password_file.should == "/path/to/password/file"
      end

      it do
        encryptor.send(:salt).should == ['-salt']
      end

      it do
        encryptor.send(:base64).should == ['-base64']
      end

      it do
        encryptor.send(:pass).should == ['-pass file:/path/to/password/file']
      end

      it do
        encryptor.send(:options).should == "aes-256-cbc -base64 -salt -pass file:/path/to/password/file"
      end
    end
    
  end

  describe '#perform!' do
    let(:encryptor) { Backup::Encryptor::OpenSSL.new }
    before do
      Backup::Model.extension = 'tar'
      [:utility, :run, :rm].each { |method| encryptor.stubs(method) }
    end

    it do
      encryptor = Backup::Encryptor::OpenSSL.new
      encryptor.expects(:utility).returns(:openssl)
      encryptor.expects(:run).with("openssl aes-256-cbc -k '' -in '#{ File.join(Backup::TMP_PATH, "#{Backup::TIME}.#{Backup::TRIGGER}.tar") }' -out '#{ File.join(Backup::TMP_PATH, "#{Backup::TIME}.#{Backup::TRIGGER}.tar.enc") }'")
      encryptor.perform!
    end

    it do
      encryptor = Backup::Encryptor::OpenSSL.new do |e|
        e.password = "my_secret_password"
        e.salt     = true
        e.base64   = true
      end
      encryptor.stubs(:utility).returns(:openssl)
      encryptor.expects(:run).with("openssl aes-256-cbc -base64 -salt -k 'my_secret_password' -in '#{ File.join(Backup::TMP_PATH, "#{Backup::TIME}.#{Backup::TRIGGER}.tar") }' -out '#{ File.join(Backup::TMP_PATH, "#{Backup::TIME}.#{Backup::TRIGGER}.tar.enc") }'")
      encryptor.perform!
    end
    
    it do
      encryptor = Backup::Encryptor::OpenSSL.new do |e|
        e.password_file = "/path/to/password/file"
        e.salt     = true
        e.base64   = true
      end
      encryptor.stubs(:utility).returns(:openssl)
      encryptor.expects(:run).with("openssl aes-256-cbc -base64 -salt -pass file:/path/to/password/file -in '#{ File.join(Backup::TMP_PATH, "#{Backup::TIME}.#{Backup::TRIGGER}.tar") }' -out '#{ File.join(Backup::TMP_PATH, "#{Backup::TIME}.#{Backup::TRIGGER}.tar.enc") }'")
      encryptor.perform!
    end

    it 'should append the .enc extension after the encryption' do
      Backup::Model.extension.should == 'tar'
      encryptor.perform!
      Backup::Model.extension.should == 'tar.enc'
    end

    it do
      encryptor.expects(:utility).with(:openssl)
      encryptor.perform!
    end

    it do
      Backup::Logger.expects(:message).with("Backup::Encryptor::OpenSSL started encrypting the archive.")
      encryptor.perform!
    end

    context "after encrypting the file (which creates a new file)" do
      it 'should remove the non-encrypted file' do
        encryptor.expects(:rm).with(Backup::Model.file)
        encryptor.perform!
      end
    end
  end
end
