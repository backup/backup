# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Encryptor::GPG do
  let(:encryptor) do
    Backup::Encryptor::GPG.new do |e|
      e.key = 'gpg_key'
    end
  end

  describe '#initialize' do
    it 'should read the adapter details correctly' do
      encryptor.key.should == 'gpg_key'
    end

    context 'when options are not set' do
      it 'should use default values' do
        encryptor = Backup::Encryptor::GPG.new
        encryptor.key.should be_nil
      end
    end

    context 'when configuration defaults have been set' do
      after { Backup::Configuration::Encryptor::GPG.clear_defaults! }

      it 'should use configuration defaults' do
        Backup::Configuration::Encryptor::GPG.defaults do |encryptor|
          encryptor.key = 'my_key'
        end

        encryptor = Backup::Encryptor::GPG.new
        encryptor.key.should == 'my_key'
      end
    end
  end # describe '#initialize'

  describe '#encrypt_with' do
    it 'should yield the encryption command and extension' do
      encryptor.expects(:log!)
      encryptor.expects(:extract_encryption_key_email!)
      encryptor.expects(:utility).with(:gpg).returns('gpg')
      encryptor.expects(:options).returns('command options')

      encryptor.encrypt_with do |command, ext|
        command.should == 'gpg command options'
        ext.should == '.gpg'
      end
    end
  end

  describe '#extract_encryption_key_email!' do
    it 'should extract the encryption_key_email' do
      encryptor.expects(:utility).with(:gpg).returns('gpg')
      encryptor.expects(:with_tmp_key_file).yields('/path/to/tmpfile')
      encryptor.expects(:run).with("gpg --import '/path/to/tmpfile' 2>&1").
        returns('gpg: key A1B2C3D4: "User Name (Comment) <user@host>" not changed')

      encryptor.send(:extract_encryption_key_email!)
      encryptor.instance_variable_get(:@encryption_key_email).should == 'user@host'
    end

    it 'should use the cached key email if already extracted' do
      encryptor.instance_variable_set(:@encryption_key_email, 'foo@host')
      encryptor.expects(:utility).never
      encryptor.expects(:with_tmp_key_file).never
      encryptor.expects(:run).never

      encryptor.send(:extract_encryption_key_email!)
    end
  end

  describe '#options' do
    it 'should return the option string for the gpg command' do
      encryptor.instance_variable_set(:@encryption_key_email, 'user@host')
      encryptor.send(:options).should == "-e --trust-model always -r 'user@host'"
    end
  end

  describe '#with_tmp_key_file' do
    let(:tmp_file) { mock }
    let(:s) { sequence '' }

    before do
      tmp_file.stubs(:path).returns('/path/to/tmp_file')
      encryptor.stubs(:encryption_key).returns('provided key')
    end

    it 'should provide a tempfile with the provided key' do
      Tempfile.expects(:new).in_sequence(s).
          with('backup.pub').
          returns(tmp_file)
      FileUtils.expects(:chown).in_sequence(s).
          with(Backup::Config.user, nil, '/path/to/tmp_file')
      FileUtils.expects(:chmod).in_sequence(s).
          with(0600, '/path/to/tmp_file')
      tmp_file.expects(:write).in_sequence(s).
          with('provided key')
      tmp_file.expects(:close).in_sequence(s)
      tmp_file.expects(:delete).in_sequence(s)

      encryptor.send(:with_tmp_key_file) do |tmp_file|
        tmp_file.should == '/path/to/tmp_file'
      end
    end
  end

  describe '#encryption_key' do
    it 'should strip leading whitespace from the given key' do
      encryptor.key = <<-KEY
        -----BEGIN PGP PUBLIC KEY BLOCK-----
        \tVersion: GnuPG v1.4.11 (Darwin)

        mQENBE12G/8BCAC4mnlSMYMBwBYTHe5zURcnYYNCORPWOr0iXGiLWuKxYtrDQyLm
        X2Nws44Iz7Wp7AuJRAjkitf1cRBgXyDu8wuogXO7JqPmtsUdBCABz9w5NH6IQjgR
        WNa3g2n0nokA7Zr5FA4GXoEaYivfbvGiyNpd6P4okH+//G2p+3FIryu5xz+89D1b
        =Yvhg
        -----END PGP PUBLIC KEY BLOCK-----
      KEY

      encryptor.send(:encryption_key).should == <<-KEY
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1.4.11 (Darwin)

mQENBE12G/8BCAC4mnlSMYMBwBYTHe5zURcnYYNCORPWOr0iXGiLWuKxYtrDQyLm
X2Nws44Iz7Wp7AuJRAjkitf1cRBgXyDu8wuogXO7JqPmtsUdBCABz9w5NH6IQjgR
WNa3g2n0nokA7Zr5FA4GXoEaYivfbvGiyNpd6P4okH+//G2p+3FIryu5xz+89D1b
=Yvhg
-----END PGP PUBLIC KEY BLOCK-----
      KEY
    end
  end

end
