# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Encryptor::OpenSSL do
  let(:encryptor) do
    Backup::Encryptor::OpenSSL.new do |e|
      e.password      = 'mypassword'
      e.password_file = '/my/password/file'
      e.base64        = true
      e.salt          = true
    end
  end

  describe '#initialize' do
    it 'should read the adapter details correctly' do
      encryptor.password.should       == 'mypassword'
      encryptor.password_file.should  == '/my/password/file'
      encryptor.base64.should         == true
      encryptor.salt.should           == true
    end

    context 'when options are not set' do
      it 'should use default values' do
        encryptor = Backup::Encryptor::OpenSSL.new
        encryptor.password.should       be_nil
        encryptor.password_file.should  be_nil
        encryptor.base64.should         be_false
        encryptor.salt.should           be_true
      end
    end

    context 'when configuration defaults have been set' do
      after { Backup::Configuration::Encryptor::OpenSSL.clear_defaults! }

      it 'should use configuration defaults' do
        Backup::Configuration::Encryptor::OpenSSL.defaults do |encryptor|
          encryptor.password      = 'my_password'
          encryptor.password_file = '/my_password/file'
          encryptor.base64        = true
          encryptor.salt          = true
        end

        encryptor = Backup::Encryptor::OpenSSL.new
        encryptor.password.should       == 'my_password'
        encryptor.password_file.should  == '/my_password/file'
        encryptor.base64.should         == true
        encryptor.salt.should           == true
      end
    end
  end # describe '#initialize'

  describe '#encrypt_with' do
    it 'should yield the encryption command and extension' do
      encryptor.expects(:log!)
      encryptor.expects(:utility).with(:openssl).returns('openssl_cmd')
      encryptor.expects(:options).returns('cmd_options')

      encryptor.encrypt_with do |command, ext|
        command.should == 'openssl_cmd cmd_options'
        ext.should == '.enc'
      end
    end
  end

  describe '#options' do
    let(:encryptor) { Backup::Encryptor::OpenSSL.new }

    before do
      # salt is true by default
      encryptor.salt = false
    end

    context 'with no options given' do
      it 'should always include cipher command' do
        encryptor.send(:options).should match(/^aes-256-cbc\s.*$/)
      end

      it 'should add #password option whenever #password_file not given' do
        encryptor.send(:options).should ==
            "aes-256-cbc -k ''"
      end
    end

    context 'when #password_file is given' do
      before { encryptor.password_file = 'password_file' }

      it 'should add #password_file option' do
        encryptor.send(:options).should ==
            'aes-256-cbc -pass file:password_file'
      end

      it 'should add #password_file option even when #password given' do
        encryptor.password = 'password'
        encryptor.send(:options).should ==
            'aes-256-cbc -pass file:password_file'
      end
    end

    context 'when #password is given (without #password_file given)' do
      before { encryptor.password = 'password' }

      it 'should include the given password in the #password option' do
        encryptor.send(:options).should ==
            "aes-256-cbc -k 'password'"
      end
    end

    context 'when #base64 is true' do
      before { encryptor.base64 = true }

      it 'should add the option' do
        encryptor.send(:options).should ==
            "aes-256-cbc -base64 -k ''"
      end
    end

    context 'when #salt is true' do
      before { encryptor.salt = true }

      it 'should add the option' do
        encryptor.send(:options).should ==
            "aes-256-cbc -salt -k ''"
      end
    end

  end # describe '#options'

end
