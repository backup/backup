# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Encryptor::GPG do
  let(:encryptor) do
    Backup::Encryptor::GPG.new do |e|
      e.mode = :symmetric
      e.passphrase = 'test secret'
    end
  end

  it 'should be a subclass of Encryptor::Base' do
    Backup::Encryptor::GPG.
      superclass.should == Backup::Encryptor::Base
  end

  it 'supports three modes of operation' do
    Backup::Encryptor::GPG::MODES.should == [:asymmetric, :symmetric, :both]
  end

  describe '#mode=' do
    it 'should accept valid modes' do
      mode = Backup::Encryptor::GPG::MODES.shuffle.first
      encryptor.mode = mode
      encryptor.mode.should == mode
    end

    it 'should convert string input to a symbol' do
      mode = Backup::Encryptor::GPG::MODES.shuffle.first
      encryptor.mode = mode.to_s
      encryptor.mode.should == mode
    end

    it 'should raise an error for invalid modes' do
      expect do
        encryptor.mode = 'foo'
      end.to raise_error(Backup::Errors::Encryptor::GPG::InvalidModeError)
    end
  end # describe '#mode='

  describe '#initialize' do
    after { Backup::Encryptor::GPG.clear_defaults! }

    it 'should load pre-configured defaults' do
      Backup::Encryptor::GPG.any_instance.expects(:load_defaults!)
      encryptor
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        encryptor.mode.should == :symmetric
        encryptor.passphrase.should == 'test secret'
      end

      it 'should use default values if none are given' do
        encryptor = Backup::Encryptor::GPG.new
        encryptor.mode.should == :asymmetric
        encryptor.keys.should be_nil
        encryptor.recipients.should be_nil
        encryptor.passphrase.should be_nil
        encryptor.passphrase_file.should be_nil
        encryptor.gpg_config.should be_nil
        encryptor.gpg_homedir.should be_nil
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Encryptor::GPG.defaults do |e|
          e.mode = :both
          e.keys = { 'test_key' => 'test public key' }
          e.recipients = 'test_key'
          e.passphrase_file = 'my/pass/file'
        end
      end

      it 'should use pre-configured defaults' do
        encryptor = Backup::Encryptor::GPG.new
        encryptor.mode.should == :both
        encryptor.keys.should == { 'test_key' => 'test public key' }
        encryptor.recipients.should == 'test_key'
        encryptor.passphrase_file.should == 'my/pass/file'
      end

      it 'should override pre-configured defaults' do
        encryptor.mode.should == :symmetric
        encryptor.keys.should == { 'test_key' => 'test public key' }
        encryptor.recipients.should == 'test_key'
        encryptor.passphrase.should == 'test secret'
        encryptor.passphrase_file.should == 'my/pass/file'
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#encrypt_with' do
    before do
      encryptor.expects(:log!)
      encryptor.expects(:prepare)
      encryptor.expects(:cleanup) # ensure call
    end

    context 'when encryption can be performed' do
      it 'should yield the encryption command and extension' do
        encryptor.expects(:mode_options).twice.returns('mode_options')
        encryptor.expects(:base_options).returns('base_options')
        encryptor.expects(:utility).with(:gpg).returns('gpg')

        encryptor.encrypt_with do |command, ext|
          command.should == 'gpg base_options mode_options'
          ext.should == '.gpg'
        end
      end
    end

    context 'when encryption can not be performed' do
      it 'should raise an error when no mode_options are returned' do
        encryptor.expects(:mode_options).returns([])

        expect do
          encryptor.encrypt_with
        end.to raise_error(Backup::Errors::Encryptor::GPG::EncryptionError)
      end
    end
  end # describe '#encrypt_with'

  describe '#prepare and #cleanup' do
    it 'should setup required variables' do
      encryptor.instance_variable_set(:@tempdirs, nil)
      FileUtils.expects(:rm_rf).never
      encryptor.send(:prepare)
      encryptor.instance_variable_get(:@tempdirs).should == []
    end

    it 'should remove any tempdirs and clear all variables' do
      encryptor.instance_variable_set(:@tempdirs, ['a', 'b'])
      FileUtils.expects(:rm_rf).with(['a', 'b'], {:secure => true})

      encryptor.instance_variable_set(:@base_options, true)
      encryptor.instance_variable_set(:@mode_options, true)
      encryptor.instance_variable_set(:@user_recipients, true)
      encryptor.instance_variable_set(:@user_keys, true)
      encryptor.instance_variable_set(:@system_identifiers, true)

      encryptor.send(:cleanup)

      encryptor.instance_variable_get(:@tempdirs).should == []
      encryptor.instance_variable_get(:@base_options).should be_nil
      encryptor.instance_variable_get(:@mode_options).should be_nil
      encryptor.instance_variable_get(:@user_recipients).should be_nil
      encryptor.instance_variable_get(:@user_keys).should be_nil
      encryptor.instance_variable_get(:@system_identifiers).should be_nil
    end
  end # describe '#prepare and #cleanup'

  describe '#base_options' do
    context 'while caching the return value in @base_options' do
      before { encryptor.instance_variable_set(:@base_options, nil) }

      context 'when #gpg_homedir is given' do
        it 'should return the proper options' do
          encryptor.expects(:setup_gpg_homedir).once.returns('/a/dir')
          encryptor.expects(:setup_gpg_config).once.returns(false)

          ret = "--no-tty --homedir '/a/dir'"
          encryptor.send(:base_options).should == ret
          encryptor.send(:base_options).should == ret
          encryptor.instance_variable_get(:@base_options).should == ret
        end
      end

      context 'when #gpg_config is given' do
        it 'should return the proper options' do
          encryptor.expects(:setup_gpg_homedir).once.returns(false)
          encryptor.expects(:setup_gpg_config).once.returns('/a/file')

          ret = "--no-tty --options '/a/file'"
          encryptor.send(:base_options).should == ret
          encryptor.send(:base_options).should == ret
          encryptor.instance_variable_get(:@base_options).should == ret
        end
      end

      context 'when #gpg_homedir and #gpg_config is given' do
        it 'should return the proper options' do
          encryptor.expects(:setup_gpg_homedir).once.returns('/a/dir')
          encryptor.expects(:setup_gpg_config).once.returns('/a/file')

          ret = "--no-tty --homedir '/a/dir' --options '/a/file'"
          encryptor.send(:base_options).should == ret
          encryptor.send(:base_options).should == ret
          encryptor.instance_variable_get(:@base_options).should == ret
        end
      end

      context 'when neither #gpg_homedir and #gpg_config is given' do
        it 'should return the proper options' do
          encryptor.expects(:setup_gpg_homedir).once.returns(false)
          encryptor.expects(:setup_gpg_config).once.returns(false)

          ret = '--no-tty'
          encryptor.send(:base_options).should == ret
          encryptor.send(:base_options).should == ret
          encryptor.instance_variable_get(:@base_options).should == ret
        end
      end
    end
  end # describe '#base_options'

  describe '#setup_gpg_homedir' do
    context 'when #gpg_homedir is not set' do
      it 'should return false' do
        encryptor.gpg_homedir = nil
        encryptor.send(:setup_gpg_homedir).should be_false
      end
    end

    context 'when #gpg_homedir is set' do
      let(:path) { 'some/path' }
      let(:expanded_path) { File.expand_path(path) }

      before do
        encryptor.gpg_homedir = path
        Backup::Config.stubs(:user).returns('a_user')
      end

      context 'and no errors occur' do
        before do
          FileUtils.expects(:mkdir_p).with(expanded_path)
          FileUtils.expects(:chown).with('a_user', nil, expanded_path)
          FileUtils.expects(:chmod).with(0700, expanded_path)
        end

        context 'and the gpg_homedir files exist' do
          before do
            %w{ pubring.gpg secring.gpg trustdb.gpg }.each do |file|
              File.expects(:exist?).with(
                File.join(expanded_path, file)
              ).returns(true)
            end
          end

          it 'should ensure permissions and return the path' do
            encryptor.expects(:utility).never
            encryptor.send(:setup_gpg_homedir).should == expanded_path
          end
        end

        context 'and the gpg_homedir files do not exist' do
          before do
            File.stubs(:exist?).returns(false)
          end

          it 'should call gpg to initialize the files' do
            encryptor.expects(:utility).with(:gpg).returns('gpg')
            encryptor.expects(:run).with(
              "gpg --homedir '#{ expanded_path }' -K 2>&1 >/dev/null"
            )
            encryptor.send(:setup_gpg_homedir).should == expanded_path
          end
        end
      end

      context 'and errors occur' do
        it 'should wrap and raise the error' do
          File.expects(:expand_path).raises('error message')

          expect do
            encryptor.send(:setup_gpg_homedir)
          end.to raise_error {|err|
            err.should
              be_an_instance_of Backup::Errors::Encryptor::GPG::HomedirError
            err.message.should
              match(/Reason: RuntimeError\n  error message/)
          }
        end
      end
    end
  end # describe '#setup_gpg_homedir'

  describe '#setup_gpg_config' do
    context 'when #gpg_config is not set' do
      it 'should return false' do
        encryptor.gpg_config = nil
        encryptor.send(:setup_gpg_config).should be_false
      end
    end

    context 'when #gpg_config is set' do
      before do
        encryptor.gpg_config = <<-EOF
          # a comment
          text which will be

          \tthe content of a gpg.conf file
        EOF
        Backup::Config.stubs(:tmp_path).returns('/Backup/tmp')
        encryptor.instance_variable_set(:@tempdirs, [])
      end

      context 'when no errors occur' do
        let(:tempdir) { mock }
        let(:tempfile) { mock }
        let(:tempfile_path) { mock }
        let(:path) { mock }

        before do
          encryptor.expects(:cleanup).never
          tempfile.stubs(:path).returns(tempfile_path)
        end

        it 'should create and return the file path' do
          # create temporary directory and convert to a Pathname object
          Dir.expects(:mktmpdir).with(
            'backup-gpg_config', '/Backup/tmp'
          ).returns(tempdir)

          # create temporary file within the temporary directory
          Tempfile.expects(:open).with(
            'backup-gpg_config', tempdir
          ).returns(tempfile)

          # write the gpg_config, stripping leading tabs/spaces
          tempfile.expects(:write).with(
            "# a comment\n" +
            "text which will be\n" +
            "\n" +
            "the content of a gpg.conf file\n"
          )
          # close the file
          tempfile.expects(:close)

          # check the config file
          encryptor.expects(:check_gpg_config).with(tempfile_path)

          # method returns the tempfile's path
          encryptor.send(:setup_gpg_config).should == tempfile_path

          # tempdir added to @tempdirs
          encryptor.instance_variable_get(:@tempdirs)[0].should == tempdir
        end
      end

      context 'when errors occur' do
        before do
          encryptor.expects(:cleanup) # run before the error is raised
        end

        it 'should wrap and raise the error' do
          Dir.expects(:mktmpdir).raises('an error')

          expect do
            encryptor.send(:setup_gpg_config)
          end.to raise_error {|err|
            err.should be_an_instance_of(
              Backup::Errors::Encryptor::GPG::GPGConfigError
            )
            err.message.should match(
              /Error creating temporary file for #gpg_config/
            )
            err.message.should match(
              /Reason: RuntimeError\n  an error/
            )
          }
        end
      end
    end
  end # describe '#setup_gpg_config'

  describe '#check_gpg_config' do
    let(:cmd_ret) { mock }
    let(:file_path) { '/path/to/tempfile' }

    before do
      encryptor.expects(:utility).with(:gpg).returns('gpg')
      encryptor.expects(:run).with(
        "gpg --options '#{ file_path }' --gpgconf-test 2>&1"
      ).returns(cmd_ret)
    end

    context 'when no errors are reported' do
      before { cmd_ret.expects(:chomp).returns('') }

      it 'should do nothing' do
        encryptor.send(:check_gpg_config, file_path).should be_nil
      end
    end

    context 'when errors are reported' do
      let(:error_message) { "gpg: /path/to/tempfile:1: invalid option" }
      before { cmd_ret.expects(:chomp).returns(error_message) }

      it 'should raise the error message reported' do
        expect do
          encryptor.send(:check_gpg_config, file_path)
        end.to raise_error(RuntimeError, error_message)
      end
    end
  end # describe '#check_gpg_config'

  describe '#mode_options' do
    let(:s_opts) { "-c --passphrase_file '/some/file'" }
    let(:a_opts) { "-e --trust-model always -r 'identifier'" }

    context 'while caching the return value in @mode_options' do
      before { encryptor.instance_variable_set(:@mode_options, nil) }

      context 'when #mode is :symmetric' do
        it 'should return symmetric encryption options' do
          encryptor.expects(:symmetric_options).once.returns(s_opts)
          encryptor.expects(:asymmetric_options).never

          encryptor.mode = :symmetric
          encryptor.send(:mode_options).should == s_opts
          encryptor.send(:mode_options).should == s_opts
          encryptor.instance_variable_get(:@mode_options).should == s_opts
        end
      end

      context 'when #mode is :asymmetric' do
        it 'should return asymmetric encryption options' do
          encryptor.expects(:symmetric_options).never
          encryptor.expects(:asymmetric_options).once.returns(a_opts)

          encryptor.mode = :asymmetric
          encryptor.send(:mode_options).should == a_opts
          encryptor.send(:mode_options).should == a_opts
          encryptor.instance_variable_get(:@mode_options).should == a_opts
        end
      end

      context 'when #mode is :both' do
        it 'should return both symmetric and asymmetric encryption options' do
          encryptor.expects(:symmetric_options).once.returns(s_opts)
          encryptor.expects(:asymmetric_options).once.returns(a_opts)

          encryptor.mode = :both
          opts = "#{ s_opts } #{ a_opts }"

          encryptor.send(:mode_options).should == opts
          encryptor.send(:mode_options).should == opts
          encryptor.instance_variable_get(:@mode_options).should == opts
        end
      end
    end
  end # describe '#mode_options'

  describe '#symmetric_options' do
    let(:path) { '/path/to/passphrase/file' }
    let(:s_opts) { "-c --passphrase-file '#{ path }'" }

    context 'when setup_passphrase_file returns a path' do
      it 'should return the options' do
        encryptor.expects(:setup_passphrase_file).returns(path)
        File.expects(:exist?).with(path).returns(true)

        encryptor.send(:symmetric_options).should == s_opts
      end
    end

    context 'when setup_passphrase_file returns false' do
      before do
        encryptor.expects(:setup_passphrase_file).returns(false)
      end

      context 'and no :passphrase_file is set' do
        it 'should return nil and log a warning' do
          encryptor.expects(:passphrase_file).returns(nil)
          Backup::Logger.expects(:warn)

          encryptor.send(:symmetric_options).should be_nil
        end
      end

      context 'and a :passphrase_file is set' do
        before do
          encryptor.expects(:passphrase_file).twice.returns(path)
          File.expects(:expand_path).with(path).returns(path)
        end

        context 'when :passphrase_file exists' do
          it 'should return the options' do
            File.expects(:exist?).with(path).returns(true)
            encryptor.send(:symmetric_options).should == s_opts
          end
        end

        context 'when :passphrase_file is no valid' do
          it 'should return nil and log a warning' do
            File.expects(:exist?).with(path).returns(false)
            Backup::Logger.expects(:warn)
            encryptor.send(:symmetric_options).should be_nil
          end
        end
      end
    end
  end # describe '#symmetric_options'

  describe '#setup_passphrase_file' do
    context 'when :passphrase is not set' do
      it 'should return false' do
        encryptor.expects(:passphrase).returns(nil)
        encryptor.send(:setup_passphrase_file).should be_false
      end
    end

    context 'when :passphrase is set' do
      let(:tempdir) { mock }
      let(:tempfile) { mock }
      let(:tempfile_path) { mock }

      before do
        encryptor.instance_variable_set(:@tempdirs, [])
        Backup::Config.stubs(:tmp_path).returns('/Backup/tmp')
        encryptor.stubs(:passphrase).returns('a secret')
        tempfile.stubs(:path).returns(tempfile_path)
      end

      context 'and no errors occur' do
        it 'should return the path for the temp file' do
          # creates temporary directory in Config.tmp_path
          Dir.expects(:mktmpdir).
              with('backup-gpg_passphrase', '/Backup/tmp').
              returns(tempdir)

          # create the temporary file in that temporary directory
          Tempfile.expects(:open).
              with('backup-gpg_passphrase', tempdir).
              returns(tempfile)
          tempfile.expects(:write).with('a secret')
          tempfile.expects(:close)

          encryptor.send(:setup_passphrase_file).should == tempfile_path

          # adds the temporary directory to @tempdirs
          encryptor.instance_variable_get(:@tempdirs)[0].should == tempdir
        end
      end

      context 'and an error occurs' do
        it 'should return false and log a warning' do
          Dir.expects(:mktmpdir).raises('an error')
          Backup::Logger.expects(:warn).with do |err|
            err.should be_an_instance_of(
              Backup::Errors::Encryptor::GPG::PassphraseError
            )
            err.message.should match(
              /Reason: RuntimeError\n  an error/
            )
          end
          encryptor.send(:setup_passphrase_file).should be_false
        end
      end

    end
  end # describe '#setup_passphrase_file'

  describe '#asymmetric_options' do
    context 'when recipients are found' do
      it 'should return the options' do
        encryptor.stubs(:user_recipients).returns(['keyid1', 'keyid2'])
        encryptor.send(:asymmetric_options).should ==
          "-e --trust-model always -r 'keyid1' -r 'keyid2'"
      end
    end

    context 'when no recipients are found' do
      it 'should return nil log a warning' do
        encryptor.expects(:user_recipients).returns([])
        Backup::Logger.expects(:warn)
        encryptor.send(:asymmetric_options).should be_nil
      end
    end
  end # describe '#asymmetric_options'

  describe '#user_recipients' do
    context 'when an Array of :recipients are given' do
      it 'should return the recipient list and cache the result' do
        encryptor.expects(:recipients).returns(
          ['key_id1', 'key_id2', 'key_id3', 'key_id4']
        )
        encryptor.expects(:clean_identifier).with('key_id1').returns('key_id1')
        encryptor.expects(:clean_identifier).with('key_id2').returns('key_id2')
        encryptor.expects(:clean_identifier).with('key_id3').returns('key_id3')
        encryptor.expects(:clean_identifier).with('key_id4').returns('key_id4')

        # key_id1 and key_id3 will be found in the system
        encryptor.stubs(:system_identifiers).returns(['key_id1', 'key_id3'])

        # key_id2 will be imported (key_id returned)
        encryptor.stubs(:user_keys).returns({ 'key_id2' => 'a public key' })
        encryptor.expects(:import_key).
            with('key_id2', 'a public key').
            returns('key_id2')

        # key_id4 will not be found in user_keys, so a warning will be logged.
        # This will return nil into the array, which will be compacted out.
        Backup::Logger.expects(:warn).with do |msg|
          msg.should match(/'key_id4'/)
        end

        encryptor.instance_variable_set(:@user_recipients, nil)
        recipient_list = ['key_id1', 'key_id2', 'key_id3']
        encryptor.send(:user_recipients).should == recipient_list
        # results are cached (expectations would fail if called twice)
        encryptor.send(:user_recipients).should == recipient_list
        encryptor.instance_variable_get(:@user_recipients).should == recipient_list
      end
    end

    context 'when :recipients is a single recipient, given as a String' do
      it 'should return the cleaned identifier in an Array' do
        encryptor.expects(:recipients).returns('key_id')
        # the key will be found in system_identifiers
        encryptor.stubs(:system_identifiers).returns(['key_id'])
        encryptor.expects(:clean_identifier).with('key_id').returns('key_id')

        encryptor.send(:user_recipients).should == ['key_id']
      end
    end

    context 'when :recipients is not set' do
      it 'should return an empty Array' do
        encryptor.expects(:recipients).returns(nil)
        encryptor.send(:user_recipients).should == []
      end
    end
  end # describe '#user_recipients'

  describe '#user_keys' do
    context 'when :keys has been set' do
      before do
        encryptor.expects(:keys).returns(
          { 'key1' => :foo, 'key2' => :foo, 'key3' => :foo }
        )
        encryptor.instance_variable_set(:@user_keys, nil)
      end

      it 'should return a new Hash of #keys with cleaned identifiers' do
        encryptor.expects(:clean_identifier).with('key1').returns('clean_key1')
        encryptor.expects(:clean_identifier).with('key2').returns('clean_key2')
        encryptor.expects(:clean_identifier).with('key3').returns('clean_key3')

        Backup::Logger.expects(:warn).never

        cleaned_hash = {
          'clean_key1' => :foo, 'clean_key2' => :foo, 'clean_key3' => :foo
        }
        encryptor.send(:user_keys).should == cleaned_hash
        # results are cached (expectations would fail if called twice)
        encryptor.send(:user_keys).should == cleaned_hash
        encryptor.instance_variable_get(:@user_keys).should == cleaned_hash
      end

      it 'should log a warning if cleaning results in a duplicate identifier' do
        encryptor.expects(:clean_identifier).with('key1').returns('clean_key1')
        encryptor.expects(:clean_identifier).with('key2').returns('clean_key2')
        # return a duplicate key
        encryptor.expects(:clean_identifier).with('key3').returns('clean_key2')

        Backup::Logger.expects(:warn)

        cleaned_hash = {
          'clean_key1' => :foo, 'clean_key2' => :foo
        }
        encryptor.send(:user_keys).should == cleaned_hash
        # results are cached (expectations would fail if called twice)
        encryptor.send(:user_keys).should == cleaned_hash
        encryptor.instance_variable_get(:@user_keys).should == cleaned_hash
      end
    end

    context 'when :keys has not be set' do
      before do
        encryptor.expects(:keys).returns(nil)
        encryptor.instance_variable_set(:@user_keys, nil)
      end

      it 'should return an empty hash' do
        encryptor.send(:user_keys).should == {}
      end
    end
  end # describe '#user_keys'

  describe '#clean_identifier' do
    it 'should remove all spaces and upcase non-email identifiers' do
      encryptor.send(:clean_identifier, ' 9d66 6290 c5f7 ee0f ').
          should == '9D666290C5F7EE0F'
    end

    # Even though spaces in an email are technically possible,
    # GPG won't allow anything but /[A-Za-z0-9_\-.]/
    it 'should remove all spaces and wrap email addresses in <>' do
      emails = [
        "\t Foo.Bar@example.com ",
        " < Foo-Bar@example.com\t > ",
        "< <Foo_Bar @\texample.com> >"
      ]
      cleaned = [
        '<Foo.Bar@example.com>',
        '<Foo-Bar@example.com>',
        '<Foo_Bar@example.com>'
      ]

      emails.map {|email|
         encryptor.send(:clean_identifier, email)
      }.should == cleaned
    end
  end # describe '#clean_identifier'

  describe '#import_key' do
    let(:gpg_return_ok) {
      <<-EOS.gsub(/^ +/, '')
        gpg: keyring `/tmp/.gnupg/secring.gpg' created
        gpg: keyring `/tmp/.gnupg/pubring.gpg' created
        gpg: /tmp/.gnupg/trustdb.gpg: trustdb created
        gpg: key 0x9D666290C5F7EE0F: public key "Backup Test <backup01@foo.com>" imported
        gpg: Total number processed: 1
        gpg:               imported: 1  (RSA: 1)
      EOS
    }
    let(:gpg_return_failed) {
      <<-EOS.gsub(/^ +/, '')
        gpg: no valid OpenPGP data found.
        gpg: Total number processed: 0
      EOS
    }
    let(:gpg_key) {
      <<-EOS
        -----BEGIN PGP PUBLIC KEY BLOCK-----
        Version: GnuPG v1.4.12 (GNU/Linux)

        mI0EUAmiNwEEAKpNP4GVKcjJrTtAh0XKk0NQsId6h/1pzEok2bExkNvD6eSjYRFL
        gXY+pNqaEE6cHrg+uQatVQITX8EoVJhQ9Z1mYJB+g62zqOQPe10Spb381O9y4dN/
        /ge/yL+/+R2CUrKeNF9nSA24+V4mTSqgo7sTnevDzGj4Srzs76MmkpU=
        =TU/B
        -----END PGP PUBLIC KEY BLOCK-----
      EOS
    }
    let(:tempfile) { mock }

    before do
      Backup::Config.stubs(:tmp_path).returns('/tmp/path')
      encryptor.stubs(:base_options).returns("--some 'base options'")
      encryptor.stubs(:utility).returns('gpg')
      tempfile.stubs(:path).returns('/tmp/file/path')
    end

    context 'when the import is successful' do
      it 'should return the long key ID' do
        Tempfile.expects(:open).with(
          'backup-gpg_import', '/tmp/path'
        ).returns(tempfile)
        tempfile.expects(:write).with(<<-EOS)
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1.4.12 (GNU/Linux)

mI0EUAmiNwEEAKpNP4GVKcjJrTtAh0XKk0NQsId6h/1pzEok2bExkNvD6eSjYRFL
gXY+pNqaEE6cHrg+uQatVQITX8EoVJhQ9Z1mYJB+g62zqOQPe10Spb381O9y4dN/
/ge/yL+/+R2CUrKeNF9nSA24+V4mTSqgo7sTnevDzGj4Srzs76MmkpU=
=TU/B
-----END PGP PUBLIC KEY BLOCK-----
      EOS

        tempfile.expects(:close)

        encryptor.expects(:run).with(
          "gpg --some 'base options' --keyid-format 0xlong " +
          "--import '/tmp/file/path' 2>&1"
        ).returns(gpg_return_ok)

        tempfile.expects(:delete)

        Backup::Logger.expects(:warn).never

        encryptor.send(:import_key, 'some_identifier', gpg_key).
            should == '9D666290C5F7EE0F'
      end
    end

    context 'when the import is unsuccessful' do
      it 'should return nil and log a warning' do
        Tempfile.expects(:open).raises('an error')
        Backup::Logger.expects(:warn).with {|err|
          err.should be_an_instance_of(
            Backup::Errors::Encryptor::GPG::KeyImportError
          )
          err.message.should match(
            /Public key import failed for 'some_identifier'/
          )
          err.message.should match(
            /Reason: RuntimeError\n  an error/
          )
        }

        encryptor.send(:import_key, 'some_identifier', 'foo').should be_nil
      end
    end
  end # describe '#import_key'

  describe '#system_identifiers' do
    let(:gpg_output) {
      <<-EOS.gsub(/^ +/, '')
        tru::1:1343402941:0:3:1:5
        pub:-:1024:1:5EFD157FFF9CFEA6:1342808803:::-:::scESC:
        fpr:::::::::72E56E48E362BB402B3344045EFD157FFF9CFEA6:
        uid:-::::1342808803::3BED8A0A5100FE9028BEB53610247518594B60A8::Backup Test (No Email):
        sub:-:1024:1:E6CF1DC860A82E07:1342808803::::::e:
        pub:-:1024:1:570CE9221E3DA3E8:1342808841:::-:::scESC:
        fpr:::::::::616BBC8409C1AED791F8E6F8570CE9221E3DA3E8:
        uid:-::::1342808875::ECFF419EFE4BD3C7CBCCD58FACAD283A9E98FECD::Backup Test <backup04@foo.com>:
        uid:-::::1342808841::DDFD072C193BB45587EBA9D19A7DA1BB0E5E8A22::Backup Test <backup03@foo.com>:
        sub:-:1024:1:B65C0ADEB804268D:1342808841::::::e:
        pub:-:1024:1:54F81C93A7641A16:1342809011:::-:::scESC:
        fpr:::::::::71335B9B960CF3A3071535F454F81C93A7641A16:
        uid:-::::1342809011::2E5801E9C064C2A165B61EE35D50A5F9B64BF345::Backup Test (other email is <backup06@foo.com>) <backup05@foo.com>:
        sub:-:1024:1:5B57BC34628252C7:1342809011::::::e:
        pub:-:1024:1:0A5B6CC9581A88CF:1342809049:::-:::scESC:
        fpr:::::::::E8C459082544924B8AEA06280A5B6CC9581A88CF:
        uid:-::::1342809470::4A404F9ED6780E7E0E02A7F7607828E648789058::Backup Test <backup08@foo.com>:
        uid:-::::::9785ADEBBBCE94CE0FF25774F610F2B11C839E9B::Backup Test <backup07@foo.com>:
        uid:r::::::4AD074B1857819EFA105DFB6C464600AA451BF18::Backup Test <backup09@foo.com>:
        sub:e:1024:1:60A420E39B979B06:1342809049:1342895611:::::e:
        sub:-:1024:1:A05786E7AD5B8352:1342809166::::::e:
        pub:i:1024:1:4A83569F4E5E8D8A:1342810132:::-:::esca:
        fpr:::::::::FFEAD1DB201FB214873E73994A83569F4E5E8D8A:
        uid:-::::::3D41A10AF2437C8C5BF6050FA80FE20CE30769BF::Backup Test <backup10@foo.com>:
        sub:i:1024:1:662F18DB92C8DFD8:1342810132::::::e:
        pub:r:1024:1:15ECEF9ECA136FFF:1342810387:::-:::sc:
        fpr:::::::::3D1CBF3FEFCE5ABB728922F615ECEF9ECA136FFF:
        uid:r::::1342810387::296434E1662AE0B2FF8E93EC3BF3AFE24514D0E0::Backup Test <backup11@foo.com>:
        sub:r:1024:1:097A79EB1F7D4619:1342810387::::::e:
        sub:r:1024:1:39093E8E9057625E:1342810404::::::e:
        pub:e:1024:1:31920687A8A7941B:1342810629:1342897029::-:::sc:
        fpr:::::::::03B399CBC2F4B61019D14BCD31920687A8A7941B:
        uid:e::::1342810629::ED8151565B25281CB92DD1E534701E660126CB0C::Backup Test <backup12@foo.com>:
        sub:e:1024:1:AEF89BEE95042A0F:1342810629:1342897029:::::e:
        pub:-:1024:1:E3DBAEC3FEEA03E2:1342810728:::-:::scSC:
        fpr:::::::::444B0870D985CF70BBB7F4DCE3DBAEC3FEEA03E2:
        uid:-::::1342810796::4D1B8CC29335BF79232CA71210F75CF80318B06A::Backup Test <backup13@foo.com>:
        uid:-::::1342810728::F1422363E8DC1EC3076906505CE66855BB44CAB7::Backup Test <backup14@foo.com>:
        sub:e:1024:1:C95DED316504D17C:1342810728:1342897218:::::e:
        pub:u:1024:1:027B83DB8A82B9CB:1343402840:::u:::scESC:
        fpr:::::::::A20D90150CE4E5F851AD3A9D027B83DB8A82B9CB:
        uid:u::::1343402840::307F1E025E8BEB7DABCADC353291184AD493A28E::Backup Test <backup01@foo.com>:
        sub:u:1024:1:EF31D36414FD8B2B:1343402840::::::e:
        pub:u:1024:1:4CEA6442A4A57A76:1343402867:::u:::scESC:
        fpr:::::::::5742EAFB4CF38014B474671E4CEA6442A4A57A76:
        uid:u::::1343402932::C220D9FF5C9652AA31D3CE0487D88EFF291FA1ED::Backup Test:
        uid:u::::1343402922::E89778553F703C26517AD8321C17C81F3213A782::Backup Test <backup02@foo.com>:
        sub:u:1024:1:140DDC2E97DA3567:1343402867::::::e:
      EOS
    }

    let(:valid_identifiers) {
      %w{ FF9CFEA6 5EFD157FFF9CFEA6 72E56E48E362BB402B3344045EFD157FFF9CFEA6
          1E3DA3E8 570CE9221E3DA3E8 616BBC8409C1AED791F8E6F8570CE9221E3DA3E8
          <backup04@foo.com> <backup03@foo.com>
          A7641A16 54F81C93A7641A16 71335B9B960CF3A3071535F454F81C93A7641A16
          <backup05@foo.com>
          581A88CF 0A5B6CC9581A88CF E8C459082544924B8AEA06280A5B6CC9581A88CF
          <backup08@foo.com> <backup07@foo.com>
          FEEA03E2 E3DBAEC3FEEA03E2 444B0870D985CF70BBB7F4DCE3DBAEC3FEEA03E2
          <backup13@foo.com> <backup14@foo.com>
          8A82B9CB 027B83DB8A82B9CB A20D90150CE4E5F851AD3A9D027B83DB8A82B9CB
          <backup01@foo.com>
          A4A57A76 4CEA6442A4A57A76 5742EAFB4CF38014B474671E4CEA6442A4A57A76
          <backup02@foo.com> }
    }
    it 'should return an array of all valid identifiers' do
      encryptor.instance_variable_set(:@system_identifiers, nil)

      encryptor.expects(:utility).with(:gpg).returns('gpg')
      encryptor.expects(:base_options).returns("--base 'options'")
      encryptor.expects(:run).with(
        "gpg --base 'options' --with-colons --fixed-list-mode --fingerprint"
      ).returns(gpg_output)

      encryptor.send(:system_identifiers).should == valid_identifiers
      # results cached
      encryptor.send(:system_identifiers).should == valid_identifiers
      encryptor.instance_variable_get(:@system_identifiers).
          should == valid_identifiers
    end
  end # describe '#system_identifiers'

  describe 'deprecations' do
    describe '#key' do
      it 'should import #key, use identifier for #recipients and log a warning' do
        encryptor.expects(:import_key).
            with('deprecated :key', 'a public key').
            returns('an_identifier')

        Backup::Logger.expects(:warn).with {|err|
          err.should be_an_instance_of(Backup::Errors::ConfigurationError)
          err.message.should match(
            "GPG#key has been deprecated as of backup v.3.0.26"
          )
          err.message.should match(
            "replaced with #keys and #recipients"
          )
        }

        encryptor.key = 'a public key'
        encryptor.recipients.should == 'an_identifier'
      end
    end # describe '#key'
  end # describe 'deprecations'
end
