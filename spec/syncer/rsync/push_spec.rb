# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

module Backup
describe Syncer::RSync::Push do
  before do
    Syncer::RSync::Push.any_instance.
        stubs(:utility).with(:rsync).returns('rsync')
    Syncer::RSync::Push.any_instance.
        stubs(:utility).with(:ssh).returns('ssh')
  end

  describe '#initialize' do
    after { Syncer::RSync::Push.clear_defaults! }

    it 'should use the values given' do
      syncer = Syncer::RSync::Push.new('my syncer') do |rsync|
        rsync.mode            = :valid_mode
        rsync.host            = '123.45.678.90'
        rsync.port            = 123
        rsync.ssh_user        = 'ssh_username'
        rsync.rsync_user      = 'rsync_username'
        rsync.rsync_password  = 'rsync_password'
        rsync.rsync_password_file = '/my/rsync_password'
        rsync.mirror          = true
        rsync.compress        = true
        rsync.path            = "~/my_backups/"
        rsync.additional_ssh_options = 'ssh options'
        rsync.additional_rsync_options = 'rsync options'

        rsync.directories do |directory|
          directory.add '/some/directory/'
          directory.add '~/home/directory'
          directory.exclude '*~'
          directory.exclude 'tmp/'
        end
      end

      expect( syncer.syncer_id      ).to eq 'my syncer'
      expect( syncer.mode           ).to eq :valid_mode
      expect( syncer.host           ).to eq '123.45.678.90'
      expect( syncer.port           ).to be 123
      expect( syncer.ssh_user       ).to eq 'ssh_username'
      expect( syncer.rsync_user     ).to eq 'rsync_username'
      expect( syncer.rsync_password ).to eq 'rsync_password'
      expect( syncer.rsync_password_file ).to eq '/my/rsync_password'
      expect( syncer.mirror         ).to be true
      expect( syncer.compress       ).to be true
      expect( syncer.path           ).to eq '~/my_backups/'
      expect( syncer.additional_ssh_options   ).to eq 'ssh options'
      expect( syncer.additional_rsync_options ).to eq 'rsync options'
      expect( syncer.directories ).to eq ['/some/directory/', '~/home/directory']
      expect( syncer.excludes    ).to eq ['*~', 'tmp/']
    end

    it 'should use default values if none are given' do
      syncer = Syncer::RSync::Push.new

      expect( syncer.syncer_id      ).to be_nil
      expect( syncer.mode           ).to eq :ssh
      expect( syncer.host           ).to be_nil
      expect( syncer.port           ).to be 22
      expect( syncer.ssh_user       ).to be_nil
      expect( syncer.rsync_user     ).to be_nil
      expect( syncer.rsync_password ).to be_nil
      expect( syncer.rsync_password_file ).to be_nil
      expect( syncer.mirror         ).to be(false)
      expect( syncer.compress       ).to be(false)
      expect( syncer.path           ).to eq '~/backups'
      expect( syncer.additional_ssh_options   ).to be_nil
      expect( syncer.additional_rsync_options ).to be_nil
      expect( syncer.directories ).to eq []
      expect( syncer.excludes    ).to eq []
    end

    it 'should use default port 22 for :ssh_daemon mode' do
      syncer = Syncer::RSync::Push.new do |s|
        s.mode = :ssh_daemon
      end
      expect( syncer.mode ).to eq :ssh_daemon
      expect( syncer.port ).to be 22
    end

    it 'should use default port 873 for :rsync_daemon mode' do
      syncer = Syncer::RSync::Push.new do |s|
        s.mode = :rsync_daemon
      end
      expect( syncer.mode ).to eq :rsync_daemon
      expect( syncer.port ).to be 873
    end

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Syncer::RSync::Push.defaults do |rsync|
          rsync.mode            = :default_mode
          rsync.host            = 'default_host'
          rsync.port            = 456
          rsync.ssh_user        = 'default_ssh_username'
          rsync.rsync_user      = 'default_rsync_username'
          rsync.rsync_password  = 'default_rsync_password'
          rsync.rsync_password_file = '/my/default_rsync_password'
          rsync.mirror          = true
          rsync.compress        = true
          rsync.path            = "~/default_my_backups"
          rsync.additional_ssh_options = 'default ssh options'
          rsync.additional_rsync_options = 'default rsync options'
        end
      end

      it 'should use pre-configured defaults' do
        syncer = Syncer::RSync::Push.new

        expect( syncer.mode           ).to eq :default_mode
        expect( syncer.host           ).to eq 'default_host'
        expect( syncer.port           ).to be 456
        expect( syncer.ssh_user       ).to eq 'default_ssh_username'
        expect( syncer.rsync_user     ).to eq 'default_rsync_username'
        expect( syncer.rsync_password ).to eq 'default_rsync_password'
        expect( syncer.rsync_password_file ).to eq '/my/default_rsync_password'
        expect( syncer.mirror         ).to be true
        expect( syncer.compress       ).to be true
        expect( syncer.path           ).to eq '~/default_my_backups'
        expect( syncer.additional_ssh_options   ).to eq 'default ssh options'
        expect( syncer.additional_rsync_options ).to eq 'default rsync options'
        expect( syncer.directories ).to eq []
      end

      it 'should override pre-configured defaults' do
        syncer = Syncer::RSync::Push.new do |rsync|
          rsync.mode            = :valid_mode
          rsync.host            = '123.45.678.90'
          rsync.port            = 123
          rsync.ssh_user        = 'ssh_username'
          rsync.rsync_user      = 'rsync_username'
          rsync.rsync_password  = 'rsync_password'
          rsync.rsync_password_file = '/my/rsync_password'
          rsync.mirror          = true
          rsync.compress        = true
          rsync.path            = "~/my_backups"
          rsync.additional_ssh_options = 'ssh options'
          rsync.additional_rsync_options = 'rsync options'

          rsync.directories do |directory|
            directory.add "/some/directory"
            directory.add "~/home/directory"
          end
        end

        expect( syncer.mode           ).to eq :valid_mode
        expect( syncer.host           ).to eq '123.45.678.90'
        expect( syncer.port           ).to be 123
        expect( syncer.ssh_user       ).to eq 'ssh_username'
        expect( syncer.rsync_user     ).to eq 'rsync_username'
        expect( syncer.rsync_password ).to eq 'rsync_password'
        expect( syncer.rsync_password_file ).to eq '/my/rsync_password'
        expect( syncer.mirror         ).to be true
        expect( syncer.compress       ).to be true
        expect( syncer.path           ).to eq '~/my_backups'
        expect( syncer.additional_ssh_options   ).to eq 'ssh options'
        expect( syncer.additional_rsync_options ).to eq 'rsync options'
        expect( syncer.directories ).to eq ['/some/directory', '~/home/directory']
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#perform!' do

    # Using :ssh mode, as these are not mode dependant.
    describe 'mirror and compress options' do

      specify 'with both' do
        syncer = Syncer::RSync::Push.new do |s|
          s.mode = :ssh
          s.host = 'my_host'
          s.ssh_user = 'ssh_username'
          s.mirror = true
          s.compress = true
          s.path = '~/path/in/remote/home/'
          s.directories do |dirs|
            dirs.add '/this/dir/'
            dirs.add 'that/dir'
          end
        end

        syncer.expects(:create_dest_path!)
        syncer.expects(:run).with(
          "rsync --archive --delete --compress " +
          "-e \"ssh -p 22 -l ssh_username\" " +
          "'/this/dir' '#{ File.expand_path('that/dir') }' " +
          "my_host:'path/in/remote/home'"
        )
        syncer.perform!
      end

      specify 'without mirror' do
        syncer = Syncer::RSync::Push.new do |s|
          s.mode = :ssh
          s.host = 'my_host'
          s.ssh_user = 'ssh_username'
          s.compress = true
          s.path = 'relative/path/in/remote/home'
          s.directories do |dirs|
            dirs.add '/this/dir/'
            dirs.add 'that/dir'
          end
        end

        syncer.expects(:create_dest_path!)
        syncer.expects(:run).with(
          "rsync --archive --compress " +
          "-e \"ssh -p 22 -l ssh_username\" " +
          "'/this/dir' '#{ File.expand_path('that/dir') }' " +
          "my_host:'relative/path/in/remote/home'"
        )
        syncer.perform!
      end

      specify 'without compress' do
        syncer = Syncer::RSync::Push.new do |s|
          s.mode = :ssh
          s.host = 'my_host'
          s.mirror = true
          s.path = '/absolute/path/on/remote/'
          s.directories do |dirs|
            dirs.add '/this/dir/'
            dirs.add 'that/dir'
          end
        end

        syncer.expects(:create_dest_path!)
        syncer.expects(:run).with(
          "rsync --archive --delete " +
          "-e \"ssh -p 22\" " +
          "'/this/dir' '#{ File.expand_path('that/dir') }' " +
          "my_host:'/absolute/path/on/remote'"
        )
        syncer.perform!
      end

      specify 'without both' do
        syncer = Syncer::RSync::Push.new do |s|
          s.mode = :ssh
          s.host = 'my_host'
          s.path = '/absolute/path/on/remote'
          s.directories do |dirs|
            dirs.add '/this/dir/'
            dirs.add 'that/dir'
          end
        end

        syncer.expects(:create_dest_path!)
        syncer.expects(:run).with(
          "rsync --archive " +
          "-e \"ssh -p 22\" " +
          "'/this/dir' '#{ File.expand_path('that/dir') }' " +
          "my_host:'/absolute/path/on/remote'"
        )
        syncer.perform!
      end

    end # describe 'mirror and compress options'

    describe 'additional_rsync_options' do

      specify 'given as an Array (with mirror option)' do
        syncer = Syncer::RSync::Push.new do |s|
          s.mode = :ssh
          s.host = 'my_host'
          s.mirror = true
          s.additional_rsync_options = ['--opt-a', '--opt-b']
          s.path = 'path/on/remote/'
          s.directories do |dirs|
            dirs.add '/this/dir'
            dirs.add 'that/dir'
          end
        end

        syncer.expects(:create_dest_path!)
        syncer.expects(:run).with(
          "rsync --archive --delete --opt-a --opt-b " +
          "-e \"ssh -p 22\" " +
          "'/this/dir' '#{ File.expand_path('that/dir') }' " +
          "my_host:'path/on/remote'"
        )
        syncer.perform!
      end

      specify 'given as a String (without mirror option)' do
        syncer = Syncer::RSync::Push.new do |s|
          s.mode = :ssh
          s.host = 'my_host'
          s.additional_rsync_options = '--opt-a --opt-b'
          s.path = 'path/on/remote/'
          s.directories do |dirs|
            dirs.add '/this/dir/'
            dirs.add 'that/dir'
          end
        end

        syncer.expects(:create_dest_path!)
        syncer.expects(:run).with(
          "rsync --archive --opt-a --opt-b " +
          "-e \"ssh -p 22\" " +
          "'/this/dir' '#{ File.expand_path('that/dir') }' " +
          "my_host:'path/on/remote'"
        )
        syncer.perform!
      end

      specify 'with excludes' do
        syncer = Syncer::RSync::Push.new do |s|
          s.mode = :ssh
          s.host = 'my_host'
          s.additional_rsync_options = '--opt-a --opt-b'
          s.path = 'path/on/remote/'
          s.directories do |dirs|
            dirs.add '/this/dir/'
            dirs.add 'that/dir'
            dirs.exclude '*~'
            dirs.exclude 'tmp/'
          end
        end

        syncer.expects(:create_dest_path!)
        syncer.expects(:run).with(
          "rsync --archive --exclude='*~' --exclude='tmp/' --opt-a --opt-b " +
          "-e \"ssh -p 22\" " +
          "'/this/dir' '#{ File.expand_path('that/dir') }' " +
          "my_host:'path/on/remote'"
        )
        syncer.perform!
      end

    end # describe 'additional_rsync_options'

    describe 'rsync password options' do
      let(:s) { sequence '' }
      let(:password_file) { mock }

      context 'when an rsync_password is given' do
        let(:syncer) {
          Syncer::RSync::Push.new do |syncer|
            syncer.mode = :rsync_daemon
            syncer.host = 'my_host'
            syncer.rsync_user = 'rsync_username'
            syncer.rsync_password = 'my_password'
            syncer.mirror = true
            syncer.compress = true
            syncer.path = 'my_module'
            syncer.directories do |dirs|
              dirs.add '/this/dir'
              dirs.add 'that/dir'
            end
          end
        }

        before do
          password_file.stubs(:path).returns('path/to/password_file')
          Tempfile.expects(:new).in_sequence(s).
              with('backup-rsync-password').returns(password_file)
          password_file.expects(:write).in_sequence(s).with('my_password')
          password_file.expects(:close).in_sequence(s)
        end

        it 'creates and uses a temp file for the password' do
          syncer.expects(:run).in_sequence(s).with(
            "rsync --archive --delete --compress " +
            "--password-file='#{ File.expand_path('path/to/password_file') }' " +
            "--port 873 " +
            "'/this/dir' '#{ File.expand_path('that/dir') }' " +
            "rsync_username@my_host::'my_module'"
          )

          password_file.expects(:delete).in_sequence(s)

          syncer.perform!
        end

        it 'ensures tempfile removal' do
          syncer.expects(:run).in_sequence(s).raises('error message')

          password_file.expects(:delete).in_sequence(s)

          expect do
            syncer.perform!
          end.to raise_error(RuntimeError, 'error message')
        end
      end # context 'when an rsync_password is given'

      context 'when an rsync_password_file is given' do
        let(:syncer) {
          Syncer::RSync::Push.new do |syncer|
            syncer.mode = :ssh_daemon
            syncer.host = 'my_host'
            syncer.ssh_user = 'ssh_username'
            syncer.rsync_user = 'rsync_username'
            syncer.rsync_password_file = 'path/to/my_password'
            syncer.mirror = true
            syncer.compress = true
            syncer.path = 'my_module'
            syncer.directories do |dirs|
              dirs.add '/this/dir'
              dirs.add 'that/dir'
            end
          end
        }

        before do
          Tempfile.expects(:new).never
        end

        it 'uses the given path' do
          syncer.expects(:run).in_sequence(s).with(
            "rsync --archive --delete --compress " +
            "--password-file='#{ File.expand_path('path/to/my_password') }' " +
            "-e \"ssh -p 22 -l ssh_username\" " +
            "'/this/dir' '#{ File.expand_path('that/dir') }' " +
            "rsync_username@my_host::'my_module'"
          )
          syncer.perform!
        end
      end # context 'when an rsync_password_file is given'

      context 'when using :ssh mode' do
        let(:syncer) {
          Syncer::RSync::Push.new do |syncer|
            syncer.mode = :ssh
            syncer.host = 'my_host'
            syncer.ssh_user = 'ssh_username'
            syncer.rsync_user = 'rsync_username'
            syncer.rsync_password = 'my_password'
            syncer.rsync_password_file = 'path/to/my_password'
            syncer.mirror = true
            syncer.compress = true
            syncer.path = '~/path/in/remote/home'
            syncer.directories do |dirs|
              dirs.add '/this/dir'
              dirs.add 'that/dir'
            end
          end
        }

        before do
          Tempfile.expects(:new).never
        end

        it 'uses no rsync_user, tempfile or password_option' do
          syncer.expects(:create_dest_path!)
          syncer.expects(:run).in_sequence(s).with(
            "rsync --archive --delete --compress " +
            "-e \"ssh -p 22 -l ssh_username\" " +
            "'/this/dir' '#{ File.expand_path('that/dir') }' " +
            "my_host:'path/in/remote/home'"
          )
          syncer.perform!
        end
      end # context 'when an rsync_password_file is given'

    end # describe 'rsync password options'

    describe 'transport_options and host_command' do

      context 'using :rsync_daemon mode' do

        it 'uses the rsync --port option' do
          syncer = Syncer::RSync::Push.new do |s|
            s.mode = :rsync_daemon
            s.host = 'my_host'
            s.mirror = true
            s.compress = true
            s.additional_rsync_options = '--opt-a --opt-b'
            s.path = 'module_name/path/'
            s.directories do |dirs|
              dirs.add '/this/dir/'
              dirs.add 'that/dir'
            end
          end

          syncer.expects(:run).with(
            "rsync --archive --delete --opt-a --opt-b --compress " +
            "--port 873 " +
            "'/this/dir' '#{ File.expand_path('that/dir') }' " +
            "my_host::'module_name/path'"
          )
          syncer.perform!
        end

        it 'uses the rsync_user' do
          syncer = Syncer::RSync::Push.new do |s|
            s.mode = :rsync_daemon
            s.host = 'my_host'
            s.port = 789
            s.rsync_user = 'rsync_username'
            s.mirror = true
            s.additional_rsync_options = '--opt-a --opt-b'
            s.path = 'module_name/path/'
            s.directories do |dirs|
              dirs.add '/this/dir/'
              dirs.add 'that/dir'
            end
          end

          syncer.expects(:run).with(
            "rsync --archive --delete --opt-a --opt-b " +
            "--port 789 " +
            "'/this/dir' '#{ File.expand_path('that/dir') }' " +
            "rsync_username@my_host::'module_name/path'"
          )
          syncer.perform!
        end

      end # context 'in :rsync_daemon mode'

      context 'using :ssh_daemon mode' do

        specify 'rsync_user, additional_ssh_options as an Array' do
          syncer = Syncer::RSync::Push.new do |s|
            s.mode = :ssh_daemon
            s.host = 'my_host'
            s.mirror = true
            s.compress = true
            s.additional_ssh_options = ['--opt1', '--opt2']
            s.rsync_user = 'rsync_username'
            s.additional_rsync_options = '--opt-a --opt-b'
            s.path = 'module_name/path/'
            s.directories do |dirs|
              dirs.add '/this/dir/'
              dirs.add 'that/dir'
            end
          end

          syncer.expects(:run).with(
            "rsync --archive --delete --opt-a --opt-b --compress " +
            "-e \"ssh -p 22 --opt1 --opt2\" " +
            "'/this/dir' '#{ File.expand_path('that/dir') }' " +
            "rsync_username@my_host::'module_name/path'"
          )
          syncer.perform!
        end

        specify 'ssh_user, port, additional_ssh_options as an String' do
          syncer = Syncer::RSync::Push.new do |s|
            s.mode = :ssh_daemon
            s.host = 'my_host'
            s.port = 789
            s.mirror = true
            s.compress = true
            s.ssh_user = 'ssh_username'
            s.additional_ssh_options = "-i '/my/identity_file'"
            s.additional_rsync_options = '--opt-a --opt-b'
            s.path = 'module_name/path/'
            s.directories do |dirs|
              dirs.add '/this/dir/'
              dirs.add 'that/dir'
            end
          end

          syncer.expects(:run).with(
            "rsync --archive --delete --opt-a --opt-b --compress " +
            "-e \"ssh -p 789 -l ssh_username -i '/my/identity_file'\" " +
            "'/this/dir' '#{ File.expand_path('that/dir') }' " +
            "my_host::'module_name/path'"
          )
          syncer.perform!
        end

      end # context 'in :ssh_daemon mode'

      context 'using :ssh mode' do

        it 'uses no daemon or rsync user' do
          syncer = Syncer::RSync::Push.new do |s|
            s.mode = :ssh
            s.host = 'my_host'
            s.mirror = true
            s.compress = true
            s.ssh_user = 'ssh_username'
            s.additional_ssh_options = ['--opt1', '--opt2']
            s.rsync_user = 'rsync_username'
            s.additional_rsync_options = "--opt-a 'something'"
            s.path = '~/some/path/'
            s.directories do |dirs|
              dirs.add '/this/dir/'
              dirs.add 'that/dir'
            end
          end

          syncer.expects(:create_dest_path!)
          syncer.expects(:run).with(
            "rsync --archive --delete --opt-a 'something' --compress " +
            "-e \"ssh -p 22 -l ssh_username --opt1 --opt2\" " +
            "'/this/dir' '#{ File.expand_path('that/dir') }' " +
            "my_host:'some/path'"
          )
          syncer.perform!
        end

      end # context 'in :ssh mode'

    end # describe 'transport_options and host_command'

    describe 'dest_path creation' do
      context 'when using :ssh mode' do
        it 'creates path using ssh with transport args' do
          syncer = Syncer::RSync::Push.new do |s|
            s.mode = :ssh
            s.host = 'my_host'
            s.ssh_user = 'ssh_username'
            s.additional_ssh_options = "-i '/path/to/id_rsa'"
            s.path = '~/some/path/'
            s.directories do |dirs|
              dirs.add '/this/dir/'
              dirs.add 'that/dir'
            end
          end

          syncer.expects(:run).with(
            "ssh -p 22 -l ssh_username -i '/path/to/id_rsa' my_host " +
            %q["mkdir -p 'some/path'"]
          )

          syncer.expects(:run).with(
            "rsync --archive " +
            "-e \"ssh -p 22 -l ssh_username -i '/path/to/id_rsa'\" " +
            "'/this/dir' '#{ File.expand_path('that/dir') }' " +
            "my_host:'some/path'"
          )

          syncer.perform!
        end

        it 'only creates path if mkdir -p is required' do
          syncer = Syncer::RSync::Push.new do |s|
            s.mode = :ssh
            s.host = 'my_host'
            s.ssh_user = 'ssh_username'
            s.additional_ssh_options = "-i '/path/to/id_rsa'"
            s.path = '~/path/'
            s.directories do |dirs|
              dirs.add '/this/dir/'
              dirs.add 'that/dir'
            end
          end

          syncer.expects(:run).with(
            "rsync --archive " +
            "-e \"ssh -p 22 -l ssh_username -i '/path/to/id_rsa'\" " +
            "'/this/dir' '#{ File.expand_path('that/dir') }' " +
            "my_host:'path'"
          )

          syncer.perform!
        end
      end
    end # describe 'dest_path creation'

    describe 'logging messages' do
      it 'logs started/finished messages' do
        syncer = Syncer::RSync::Push.new

        Logger.expects(:info).with('Syncer::RSync::Push Started...')
        Logger.expects(:info).with('Syncer::RSync::Push Finished!')
        syncer.perform!
      end

      it 'logs messages using optional syncer_id' do
        syncer = Syncer::RSync::Push.new('My Syncer')

        Logger.expects(:info).with('Syncer::RSync::Push (My Syncer) Started...')
        Logger.expects(:info).with('Syncer::RSync::Push (My Syncer) Finished!')
        syncer.perform!
      end
    end

  end # describe '#perform!'

  describe 'deprecations' do

    describe '#additional_options' do
      before do
        Logger.expects(:warn).with {|err|
          expect( err ).to be_an_instance_of Configuration::Error
          expect( err.message ).to match(
            /Use #additional_rsync_options instead/
          )
        }
      end

      context 'when set directly' do
        it 'warns and transfers option value' do
          syncer = Syncer::RSync::Push.new do |s|
            s.additional_options = ['some', 'options']
          end
          expect( syncer.additional_rsync_options ).to eq ['some', 'options']
        end
      end

      context 'when set using defaults' do
        after { Syncer::RSync::Push.clear_defaults! }

        it 'warns and transfers option value' do
          Syncer::RSync::Push.defaults do |s|
            s.additional_options = ['some', 'defaults']
          end
          syncer = Syncer::RSync::Push.new
          expect( syncer.additional_rsync_options ).to eq ['some', 'defaults']
        end
      end
    end # describe '#additional_options'

    describe '#username' do
      before do
        Logger.expects(:warn).with {|err|
          expect( err ).to be_an_instance_of Configuration::Error
          expect( err.message ).to match(
            /Use #ssh_user instead/
          )
        }
      end

      context 'when set directly' do
        it 'warns and transfers option value' do
          syncer = Syncer::RSync::Push.new do |s|
            s.username = 'user_name'
          end
          expect( syncer.ssh_user ).to eq 'user_name'
        end
      end

      context 'when set using defaults' do
        after { Syncer::RSync::Push.clear_defaults! }

        it 'warns and transfers option value' do
          Syncer::RSync::Push.defaults do |s|
            s.username = 'default_user'
          end
          syncer = Syncer::RSync::Push.new
          expect( syncer.ssh_user ).to eq 'default_user'
        end
      end
    end # describe '#username'

    describe '#password' do
      before do
        Logger.expects(:warn).with {|err|
          expect( err ).to be_an_instance_of Configuration::Error
          expect( err.message ).to match(
            /Use #rsync_password instead/
          )
        }
      end

      context 'when set directly' do
        it 'warns and transfers option value' do
          syncer = Syncer::RSync::Push.new do |s|
            s.password = 'secret'
          end
          expect( syncer.rsync_password ).to eq 'secret'
        end
      end

      context 'when set using defaults' do
        after { Syncer::RSync::Push.clear_defaults! }

        it 'warns and transfers option value' do
          Syncer::RSync::Push.defaults do |s|
            s.password = 'default_secret'
          end
          syncer = Syncer::RSync::Push.new
          expect( syncer.rsync_password ).to eq 'default_secret'
        end
      end
    end # describe '#password'

    describe '#ip' do
      before do
        Logger.expects(:warn).with {|err|
          expect( err ).to be_an_instance_of Configuration::Error
          expect( err.message ).to match(
            /Use #host instead/
          )
        }
      end

      context 'when set directly' do
        it 'warns and transfers option value' do
          syncer = Syncer::RSync::Push.new do |s|
            s.ip = 'hostname'
          end
          expect( syncer.host ).to eq 'hostname'
        end
      end

      context 'when set using defaults' do
        after { Syncer::RSync::Push.clear_defaults! }

        it 'warns and transfers option value' do
          Syncer::RSync::Push.defaults do |s|
            s.ip = 'hostname'
          end
          syncer = Syncer::RSync::Push.new
          expect( syncer.host ).to eq 'hostname'
        end
      end
    end # describe '#ip'

  end # describe 'deprecations'
end
end
