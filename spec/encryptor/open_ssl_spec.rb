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

  it 'should be a subclass of Encryptor::Base' do
    Backup::Encryptor::OpenSSL.
      superclass.should == Backup::Encryptor::Base
  end

  describe '#initialize' do
    after { Backup::Encryptor::OpenSSL.clear_defaults! }

    it 'should load pre-configured defaults' do
      Backup::Encryptor::OpenSSL.any_instance.expects(:load_defaults!)
      encryptor
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        encryptor.password.should       == 'mypassword'
        encryptor.password_file.should  == '/my/password/file'
        encryptor.base64.should         == true
        encryptor.salt.should           == true
      end

      it 'should use default values if none are given' do
        encryptor = Backup::Encryptor::OpenSSL.new
        encryptor.password.should       be_nil
        encryptor.password_file.should  be_nil
        encryptor.base64.should         be_false
        encryptor.salt.should           be_true
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Encryptor::OpenSSL.defaults do |e|
          e.password      = 'default_password'
          e.password_file = '/default/password/file'
          e.base64        = 'default_base64'
          e.salt          = 'default_salt'
        end
      end

      it 'should use pre-configured defaults' do
        encryptor = Backup::Encryptor::OpenSSL.new
        encryptor.password      = 'default_password'
        encryptor.password_file = '/default/password/file'
        encryptor.base64        = 'default_base64'
        encryptor.salt          = 'default_salt'
      end

      it 'should override pre-configured defaults' do
        encryptor.password.should       == 'mypassword'
        encryptor.password_file.should  == '/my/password/file'
        encryptor.base64.should         == true
        encryptor.salt.should           == true
      end
    end # context 'when pre-configured defaults have been set'
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
      before { encryptor.password = %q(pa\ss'w"ord) }

      it 'should include the given password in the #password option' do
        encryptor.send(:options).should ==
            %q(aes-256-cbc -k pa\\\ss\'w\"ord)
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
