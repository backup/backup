# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Syncer::RSync::Push do
  let(:syncer) do
    Backup::Syncer::RSync::Push.new do |rsync|
      rsync.username  = 'my_username'
      rsync.password  = 'my_password'
      rsync.ip        = '123.45.678.90'
      rsync.port      = 22
      rsync.compress  = true
      rsync.path      = "~/my_backups"

      rsync.directories do |directory|
        directory.add "/some/directory"
        directory.add "~/home/directory"
      end

      rsync.mirror             = true
      rsync.additional_options = ['--opt-a', '--opt-b']
    end
  end

  it 'should be a subclass of Syncer::RSync::Base' do
    Backup::Syncer::RSync::Push.
      superclass.should == Backup::Syncer::RSync::Base
  end

  describe '#initialize' do
    after { Backup::Syncer::RSync::Push.clear_defaults! }

    it 'should load pre-configured defaults through Syncer::Base' do
      Backup::Syncer::RSync::Push.any_instance.expects(:load_defaults!)
      syncer
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        syncer.path.should               == '~/my_backups'
        syncer.mirror.should             == true
        syncer.directories.should        == ["/some/directory", "~/home/directory"]
        syncer.additional_options.should == ['--opt-a', '--opt-b']

        syncer.username.should           == 'my_username'
        syncer.password.should           == 'my_password'
        syncer.ip.should                 == '123.45.678.90'
        syncer.port.should               == 22
        syncer.compress.should           == true
      end

      it 'should use default values if none are given' do
        syncer = Backup::Syncer::RSync::Push.new

        # from Syncer::Base
        syncer.path.should    == 'backups'
        syncer.mirror.should  == false
        syncer.directories.should == []

        # from Syncer::RSync::Base
        syncer.additional_options.should == []

        syncer.username.should           == nil
        syncer.password.should           == nil
        syncer.ip.should                 == nil
        syncer.port.should               == 22
        syncer.compress.should           == false
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Syncer::RSync::Push.defaults do |rsync|
          rsync.path    = 'some_path'
          rsync.mirror  = 'some_mirror'
          rsync.additional_options = 'some_additional_options'

          rsync.username           = 'some_username'
          rsync.password           = 'some_password'
          rsync.ip                 = 'some_ip'
          rsync.port               = 'some_port'
          rsync.compress           = 'some_compress'
        end
      end

      it 'should use pre-configured defaults' do
        syncer = Backup::Syncer::RSync::Push.new

        syncer.path.should    == 'some_path'
        syncer.mirror.should  == 'some_mirror'
        syncer.directories.should == []
        syncer.additional_options.should == 'some_additional_options'

        syncer.username.should           == 'some_username'
        syncer.password.should           == 'some_password'
        syncer.ip.should                 == 'some_ip'
        syncer.port.should               == 'some_port'
        syncer.compress.should           == 'some_compress'
      end

      it 'should override pre-configured defaults' do
        syncer = Backup::Syncer::RSync::Push.new do |rsync|
          rsync.path    = 'new_path'
          rsync.mirror  = 'new_mirror'
          rsync.additional_options = 'new_additional_options'

          rsync.username           = 'new_username'
          rsync.password           = 'new_password'
          rsync.ip                 = 'new_ip'
          rsync.port               = 'new_port'
          rsync.compress           = 'new_compress'
        end

        syncer.path.should    == 'new_path'
        syncer.mirror.should  == 'new_mirror'
        syncer.directories.should == []
        syncer.additional_options.should == 'new_additional_options'

        syncer.username.should           == 'new_username'
        syncer.password.should           == 'new_password'
        syncer.ip.should                 == 'new_ip'
        syncer.port.should               == 'new_port'
        syncer.compress.should           == 'new_compress'
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#perform!' do
    let(:s) { sequence '' }

    before do
      syncer.expects(:utility).with(:rsync).returns('rsync')
      syncer.expects(:options).returns('options_output')
    end

    it 'should sync two directories' do
      syncer.expects(:write_password_file!).in_sequence(s)

      Backup::Logger.expects(:message).in_sequence(s).with(
        "Syncer::RSync::Push started syncing the following directories:\n" +
        "  /some/directory\n" +
        "  ~/home/directory"
      )
      syncer.expects(:run).in_sequence(s).with(
        "rsync options_output '/some/directory' " +
        "'#{ File.expand_path('~/home/directory') }' " +
        "'my_username@123.45.678.90:my_backups'"
      )

      syncer.expects(:remove_password_file!).in_sequence(s)

      syncer.perform!
    end

    it 'should ensure passoword file removal' do
      syncer.expects(:write_password_file!).in_sequence(s)

      Backup::Logger.expects(:message).in_sequence(s)
      syncer.expects(:run).in_sequence(s).raises('error message')

      syncer.expects(:remove_password_file!).in_sequence(s)

      expect do
        syncer.perform!
      end.to raise_error(RuntimeError, 'error message')
    end
  end # describe '#perform!'

  describe '#dest_path' do
    it 'should remove any preceeding "~/" from @path' do
      syncer.send(:dest_path).should == 'my_backups'
    end

    it 'should set @dest_path' do
      syncer.send(:dest_path)
      syncer.instance_variable_get(:@dest_path).should == 'my_backups'
    end

    it 'should return @dest_path if already set' do
      syncer.instance_variable_set(:@dest_path, 'foo')
      syncer.send(:dest_path).should == 'foo'
    end
  end

  describe '#options' do
    let(:pwdfile) { mock }

    context 'when @compress is true' do
      it 'should return the options string with compression enabled' do
        syncer.send(:options).should ==
          "--archive --delete --compress -e 'ssh -p 22' --opt-a --opt-b"
      end
    end

    context 'when @compress is false' do
      before { syncer.compress = false }
      it 'should return the options string without compression enabled' do
        syncer.send(:options).should ==
          "--archive --delete -e 'ssh -p 22' --opt-a --opt-b"
      end
    end

    context 'when a @password_file is set' do
      before do
        syncer.instance_variable_set(:@password_file, pwdfile)
        pwdfile.expects(:path).returns('/path/to/pwdfile')
      end

      it 'should return the options string with the password_option' do
        syncer.send(:options).should ==
          "--archive --delete --compress -e 'ssh -p 22' " +
          "--password-file='/path/to/pwdfile' --opt-a --opt-b"
      end
    end

    context 'when no @additional_options are set' do
      before { syncer.additional_options = [] }

      it 'should return the options string without additional options' do
        syncer.send(:options).should ==
          "--archive --delete --compress -e 'ssh -p 22'"
      end
    end

  end # describe '#options'

  describe '#compress_option' do
    context 'when @compress is true' do
      it 'should return the compression flag' do
        syncer.send(:compress_option).should == '--compress'
      end
    end

    context 'when @compress is false' do
      before { syncer.compress = false }
      it 'should return nil' do
        syncer.send(:compress_option).should be_nil
      end
    end
  end

  describe '#port_option' do
    before { syncer.port = 40 }
    it 'should return the option string with the defined port' do
      syncer.send(:port_option).should == "-e 'ssh -p 40'"
    end
  end

  describe '#password_option' do
    let(:pwdfile) { mock }

    context 'when @password_file is set' do
      before do
        syncer.instance_variable_set(:@password_file, pwdfile)
        pwdfile.expects(:path).returns('/path/to/pwdfile')
      end

      it 'should return the option string' do
        syncer.send(:password_option).should ==
            "--password-file='/path/to/pwdfile'"
      end
    end

    context 'when @password_file is not set' do
      it 'should return nil' do
        syncer.send(:password_option).should be_nil
      end
    end
  end

  describe '#write_password_file!' do
    let(:pwdfile) { mock }
    let(:s) { sequence '' }

    context 'when a @password is set' do
      it 'should create, write and close a temporary password file' do
        Tempfile.expects(:new).in_sequence(s).
            with('backup-rsync-password').
            returns(pwdfile)
        pwdfile.expects(:write).in_sequence(s).with('my_password')
        pwdfile.expects(:close).in_sequence(s)

        syncer.send(:write_password_file!)
      end

      it 'should set @password_file to a file containing the password' do
        syncer.send(:write_password_file!)
        file = syncer.instance_variable_get(:@password_file)
        File.exist?(file.path).should be_true
        File.read(file.path).should == 'my_password'

        # cleanup
        file.delete
        file.path.should be_nil
      end
    end

    context 'when a @password is not set' do
      before { syncer.password = nil }
      it 'should return nil' do
        Tempfile.expects(:new).never
        pwdfile.expects(:write).never
        pwdfile.expects(:close).never
        syncer.send(:write_password_file!).should be_nil
      end
    end
  end

  describe '#remove_password_file!' do
    let(:pwdfile) { mock }

    context 'when @password_file is set' do
      before do
        syncer.instance_variable_set(:@password_file, pwdfile)
      end

      it 'should delete the file and reset @password_file' do
        pwdfile.expects(:delete)
        syncer.send(:remove_password_file!)
        syncer.instance_variable_get(:@password_file).should be_nil
      end
    end

    context 'when @password_file is not set' do
      it 'should return nil' do
        pwdfile.expects(:delete).never
        syncer.send(:remove_password_file!).should be_nil
        syncer.instance_variable_get(:@password_file).should be_nil
      end
    end
  end

end
