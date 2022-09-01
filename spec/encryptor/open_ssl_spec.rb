require "spec_helper"

describe Backup::Encryptor::OpenSSL do
  let(:encryptor) do
    Backup::Encryptor::OpenSSL.new do |e|
      e.password      = "mypassword"
      e.password_file = "/my/password/file"
      e.base64        = true
    end
  end

  it "should be a subclass of Encryptor::Base" do
    expect(Backup::Encryptor::OpenSSL
      .superclass).to eq(Backup::Encryptor::Base)
  end

  describe "#initialize" do
    after { Backup::Encryptor::OpenSSL.clear_defaults! }

    it "should load pre-configured defaults" do
      expect_any_instance_of(Backup::Encryptor::OpenSSL).to receive(:load_defaults!)
      encryptor
    end

    context "when no pre-configured defaults have been set" do
      it "should use the values given" do
        expect(encryptor.password).to       eq("mypassword")
        expect(encryptor.password_file).to  eq("/my/password/file")
        expect(encryptor.base64).to         eq(true)
      end

      it "should use default values if none are given" do
        encryptor = Backup::Encryptor::OpenSSL.new
        expect(encryptor.password).to       be_nil
        expect(encryptor.password_file).to  be_nil
        expect(encryptor.base64).to         eq(false)
      end
    end # context 'when no pre-configured defaults have been set'

    context "when pre-configured defaults have been set" do
      before do
        Backup::Encryptor::OpenSSL.defaults do |e|
          e.password      = "default_password"
          e.password_file = "/default/password/file"
          e.base64        = "default_base64"
        end
      end

      it "should use pre-configured defaults" do
        encryptor = Backup::Encryptor::OpenSSL.new
        encryptor.password      = "default_password"
        encryptor.password_file = "/default/password/file"
        encryptor.base64        = "default_base64"
      end

      it "should override pre-configured defaults" do
        expect(encryptor.password).to       eq("mypassword")
        expect(encryptor.password_file).to  eq("/my/password/file")
        expect(encryptor.base64).to         eq(true)
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe "#encrypt_with" do
    it "should yield the encryption command and extension" do
      expect(encryptor).to receive(:log!)
      expect(encryptor).to receive(:utility).with(:openssl).and_return("openssl_cmd")
      expect(encryptor).to receive(:options).and_return("cmd_options")

      encryptor.encrypt_with do |command, ext|
        expect(command).to eq("openssl_cmd cmd_options")
        expect(ext).to eq(".enc")
      end
    end
  end

  describe "#options" do
    let(:encryptor) { Backup::Encryptor::OpenSSL.new }

    context "with no options given" do
      it "should always include cipher command" do
        expect(encryptor.send(:options)).to match(/^aes-256-cbc\s.*$/)
      end

      it "should add #password option whenever #password_file not given" do
        expect(encryptor.send(:options)).to eq(
          "aes-256-cbc -pbkdf2 -iter 310000 -k ''"
        )
      end
    end

    context "when #password_file is given" do
      before { encryptor.password_file = "password_file" }

      it "should add #password_file option" do
        expect(encryptor.send(:options)).to eq(
          "aes-256-cbc -pbkdf2 -iter 310000 -pass file:password_file"
        )
      end

      it "should add #password_file option even when #password given" do
        encryptor.password = "password"
        expect(encryptor.send(:options)).to eq(
          "aes-256-cbc -pbkdf2 -iter 310000 -pass file:password_file"
        )
      end
    end

    context "when #password is given (without #password_file given)" do
      before { encryptor.password = %q(pa\ss'w"ord) }

      it "should include the given password in the #password option" do
        expect(encryptor.send(:options)).to eq(
          %q(aes-256-cbc -pbkdf2 -iter 310000 -k pa\\\ss\'w\"ord)
        )
      end
    end

    context "when #base64 is true" do
      before { encryptor.base64 = true }

      it "should add the option" do
        expect(encryptor.send(:options)).to eq(
          "aes-256-cbc -pbkdf2 -iter 310000 -base64 -k ''"
        )
      end
    end
  end # describe '#options'
end
