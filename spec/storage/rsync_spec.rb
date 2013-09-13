# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Storage::RSync do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:storage) { Storage::RSync.new(model) }
  let(:s) { sequence '' }

  before do
    Storage::RSync.any_instance.
        stubs(:utility).with(:rsync).returns('rsync')
    Storage::RSync.any_instance.
        stubs(:utility).with(:ssh).returns('ssh')
  end

  it_behaves_like 'a class that includes Configuration::Helpers'
  it_behaves_like 'a subclass of Storage::Base' do
    let(:no_cycler) { true }
  end

  describe '#initialize' do

    it 'provides default values' do
      expect( storage.storage_id                ).to be_nil
      expect( storage.mode                      ).to eq :ssh
      expect( storage.host                      ).to be_nil
      expect( storage.port                      ).to be 22
      expect( storage.ssh_user                  ).to be_nil
      expect( storage.rsync_user                ).to be_nil
      expect( storage.rsync_password            ).to be_nil
      expect( storage.rsync_password_file       ).to be_nil
      expect( storage.compress                  ).to be(false)
      expect( storage.path                      ).to eq '~/backups'
      expect( storage.additional_ssh_options    ).to be_nil
      expect( storage.additional_rsync_options  ).to be_nil

      # this storage doesn't support cycling, but `keep` is still inherited
      expect( storage.keep ).to be_nil
    end

    it 'configures the storage' do
      storage = Storage::RSync.new(model, :my_id) do |rsync|
        rsync.mode                      = :valid_mode
        rsync.host                      = '123.45.678.90'
        rsync.port                      = 123
        rsync.ssh_user                  = 'ssh_username'
        rsync.rsync_user                = 'rsync_username'
        rsync.rsync_password            = 'rsync_password'
        rsync.rsync_password_file       = '/my/rsync_password'
        rsync.compress                  = true
        rsync.path                      = "~/my_backups/"
        rsync.additional_ssh_options    = 'ssh options'
        rsync.additional_rsync_options  = 'rsync options'
      end

      expect( storage.storage_id                ).to eq 'my_id'
      expect( storage.mode                      ).to eq :valid_mode
      expect( storage.host                      ).to eq '123.45.678.90'
      expect( storage.port                      ).to be 123
      expect( storage.ssh_user                  ).to eq 'ssh_username'
      expect( storage.rsync_user                ).to eq 'rsync_username'
      expect( storage.rsync_password            ).to eq 'rsync_password'
      expect( storage.rsync_password_file       ).to eq '/my/rsync_password'
      expect( storage.compress                  ).to be true
      expect( storage.path                      ).to eq '~/my_backups/'
      expect( storage.additional_ssh_options    ).to eq 'ssh options'
      expect( storage.additional_rsync_options  ).to eq 'rsync options'
    end

    it 'uses default port 22 for :ssh_daemon mode' do
      storage = Storage::RSync.new(model) do |s|
        s.mode = :ssh_daemon
      end
      expect( storage.mode ).to eq :ssh_daemon
      expect( storage.port ).to be 22
    end

    it 'uses default port 873 for :rsync_daemon mode' do
      storage = Storage::RSync.new(model) do |s|
        s.mode = :rsync_daemon
      end
      expect( storage.mode ).to eq :rsync_daemon
      expect( storage.port ).to be 873
    end

  end #describe '#initialize'

  describe '#transfer!' do
    let(:package_files) {
      # source paths for package files never change
      ['test_trigger.tar-aa', 'test_trigger.tar-ab'].map {|name|
        File.join(Config.tmp_path, name)
      }
    }

    before do
      storage.package.stubs(:filenames).returns(
        ['test_trigger.tar-aa', 'test_trigger.tar-ab']
      )
    end

    context 'local transfer' do
      it 'performs transfer with default values' do
        # write_password_file does nothing
        Tempfile.expects(:new).never

        # create_remote_path
        FileUtils.expects(:mkdir_p).with(
          File.join(File.expand_path('~/backups'), 'test_trigger')
        )

        # First Package File
        dest = File.join(
          File.expand_path('~/backups'), 'test_trigger', 'test_trigger.tar-aa'
        )
        Logger.expects(:info).in_sequence(s).with(
          "Syncing to '#{ dest }'..."
        )
        storage.expects(:run).in_sequence(s).with(
          "rsync --archive '#{ package_files[0] }' '#{ dest }'"
        )

        # Second Package File
        dest = File.join(
          File.expand_path('~/backups'), 'test_trigger', 'test_trigger.tar-ab'
        )
        Logger.expects(:info).in_sequence(s).with(
          "Syncing to '#{ dest }'..."
        )
        storage.expects(:run).in_sequence(s).with(
          "rsync --archive '#{ package_files[1] }' '#{ dest }'"
        )

        storage.send(:transfer!)
      end

      it 'uses given path, storage id and additional_rsync_options' do
        storage = Storage::RSync.new(model, 'my storage') do |rsync|
          rsync.path = '/my/backups'
          rsync.additional_rsync_options = ['--arg1', '--arg2']
        end

        # write_password_file does nothing
        Tempfile.expects(:new).never

        # create_remote_path
        FileUtils.expects(:mkdir_p).with('/my/backups/test_trigger')

        # First Package File
        dest = '/my/backups/test_trigger/test_trigger.tar-aa'
        Logger.expects(:info).in_sequence(s).with(
          "Syncing to '#{ dest }'..."
        )
        storage.expects(:run).in_sequence(s).with(
          "rsync --archive --arg1 --arg2 '#{ package_files[0] }' '#{ dest }'"
        )

        # Second Package File
        dest = '/my/backups/test_trigger/test_trigger.tar-ab'
        Logger.expects(:info).in_sequence(s).with(
          "Syncing to '#{ dest }'..."
        )
        storage.expects(:run).in_sequence(s).with(
          "rsync --archive --arg1 --arg2 '#{ package_files[1] }' '#{ dest }'"
        )

        storage.send(:transfer!)
      end
    end # context 'local transfer'

    context 'remote transfer in :ssh mode' do
      it 'performs the transfer' do
        storage = Storage::RSync.new(model) do |rsync|
          rsync.host = 'host.name'
        end

        # write_password_file does nothing
        Tempfile.expects(:new).never

        # create_remote_path
        storage.expects(:run).in_sequence(s).with(
          %q[ssh -p 22 host.name "mkdir -p 'backups/test_trigger'"]
        )

        # First Package File
        dest = "host.name:'backups/test_trigger/test_trigger.tar-aa'"
        storage.expects(:run).in_sequence(s).with(
          %Q[rsync --archive -e "ssh -p 22" '#{ package_files[0] }' #{ dest }]
        )

        # Second Package File
        dest = "host.name:'backups/test_trigger/test_trigger.tar-ab'"
        storage.expects(:run).in_sequence(s).with(
          %Q[rsync --archive -e "ssh -p 22" '#{ package_files[1] }' #{ dest }]
        )

        storage.send(:transfer!)
      end

      it 'uses additional options' do
        storage = Storage::RSync.new(model) do |rsync|
          rsync.host = 'host.name'
          rsync.port = 123
          rsync.ssh_user = 'ssh_username'
          rsync.additional_ssh_options = "-i '/my/id_rsa'"
          rsync.compress = true
          rsync.additional_rsync_options = '--opt1'
        end

        # write_password_file does nothing
        Tempfile.expects(:new).never

        # create_remote_path
        storage.expects(:run).in_sequence(s).with(
          "ssh -p 123 -l ssh_username -i '/my/id_rsa' " +
          %q[host.name "mkdir -p 'backups/test_trigger'"]
        )

        # First Package File
        dest = "host.name:'backups/test_trigger/test_trigger.tar-aa'"
        storage.expects(:run).in_sequence(s).with(
          "rsync --archive --opt1 --compress " +
          %Q[-e "ssh -p 123 -l ssh_username -i '/my/id_rsa'" ] +
          "'#{ package_files[0] }' #{ dest }"
        )

        # Second Package File
        dest = "host.name:'backups/test_trigger/test_trigger.tar-ab'"
        storage.expects(:run).in_sequence(s).with(
          "rsync --archive --opt1 --compress " +
          %Q[-e "ssh -p 123 -l ssh_username -i '/my/id_rsa'" ] +
          "'#{ package_files[1] }' #{ dest }"
        )

        storage.send(:transfer!)
      end

    end # context 'remote transfer in :ssh mode'

    context 'remote transfer in :ssh_daemon mode' do
      it 'performs the transfer' do
        storage = Storage::RSync.new(model) do |rsync|
          rsync.mode = :ssh_daemon
          rsync.host = 'host.name'
          rsync.path = 'module/path'
        end

        # write_password_file does nothing
        Tempfile.expects(:new).never

        # create_remote_path does nothing
        # (a call to #run would be an unexpected expectation)
        FileUtils.expects(:mkdir_p).never

        # First Package File
        dest = "host.name::'module/path/test_trigger.tar-aa'"
        storage.expects(:run).in_sequence(s).with(
          %Q[rsync --archive -e "ssh -p 22" '#{ package_files[0] }' #{ dest }]
        )

        # Second Package File
        dest = "host.name::'module/path/test_trigger.tar-ab'"
        storage.expects(:run).in_sequence(s).with(
          %Q[rsync --archive -e "ssh -p 22" '#{ package_files[1] }' #{ dest }]
        )

        storage.send(:transfer!)
      end

      it 'uses additional options, with password' do
        storage = Storage::RSync.new(model) do |rsync|
          rsync.mode = :ssh_daemon
          rsync.host = 'host.name'
          rsync.port = 123
          rsync.ssh_user = 'ssh_username'
          rsync.additional_ssh_options = "-i '/my/id_rsa'"
          rsync.rsync_user = 'rsync_username'
          rsync.rsync_password = 'secret'
          rsync.compress = true
          rsync.additional_rsync_options = '--opt1'
        end

        # write_password_file
        password_file = stub(:path => '/path/to/password_file')
        Tempfile.expects(:new).in_sequence(s).
            with('backup-rsync-password').returns(password_file)
        password_file.expects(:write).in_sequence(s).with('secret')
        password_file.expects(:close).in_sequence(s)

        # create_remote_path does nothing

        # First Package File
        dest = "rsync_username@host.name::'backups/test_trigger.tar-aa'"
        storage.expects(:run).in_sequence(s).with(
          "rsync --archive --opt1 --compress " +
          "--password-file='/path/to/password_file' " +
          %Q[-e "ssh -p 123 -l ssh_username -i '/my/id_rsa'" ] +
          "'#{ package_files[0] }' #{ dest }"
        )

        # Second Package File
        dest = "rsync_username@host.name::'backups/test_trigger.tar-ab'"
        storage.expects(:run).in_sequence(s).with(
          "rsync --archive --opt1 --compress " +
          "--password-file='/path/to/password_file' " +
          %Q[-e "ssh -p 123 -l ssh_username -i '/my/id_rsa'" ] +
          "'#{ package_files[1] }' #{ dest }"
        )

        # remove_password_file
        password_file.expects(:delete).in_sequence(s)

        storage.send(:transfer!)
      end

      it 'ensures temporary password file is removed' do
        storage = Storage::RSync.new(model) do |rsync|
          rsync.mode = :ssh_daemon
          rsync.host = 'host.name'
          rsync.rsync_password = 'secret'
        end

        # write_password_file
        password_file = stub(:path => '/path/to/password_file')
        Tempfile.expects(:new).in_sequence(s).
            with('backup-rsync-password').returns(password_file)
        password_file.expects(:write).in_sequence(s).with('secret')
        password_file.expects(:close).in_sequence(s)

        # create_remote_path does nothing

        # First Package File (fails)
        dest = "host.name::'backups/test_trigger.tar-aa'"
        storage.expects(:run).in_sequence(s).with(
          "rsync --archive " +
          "--password-file='/path/to/password_file' " +
          %Q[-e "ssh -p 22" ] +
          "'#{ package_files[0] }' #{ dest }"
        ).raises('an error')

        # remove_password_file
        password_file.expects(:delete).in_sequence(s)

        expect do
          storage.send(:transfer!)
        end.to raise_error('an error')
      end

      it 'uses additional options, with password_file' do
        storage = Storage::RSync.new(model) do |rsync|
          rsync.mode = :ssh_daemon
          rsync.host = 'host.name'
          rsync.port = 123
          rsync.ssh_user = 'ssh_username'
          rsync.additional_ssh_options = "-i '/my/id_rsa'"
          rsync.rsync_user = 'rsync_username'
          rsync.rsync_password_file = 'my/pwd_file'
          rsync.compress = true
          rsync.additional_rsync_options = '--opt1'
        end

        # write_password_file does nothing
        Tempfile.expects(:new).never

        # create_remote_path does nothing

        # First Package File
        dest = "rsync_username@host.name::'backups/test_trigger.tar-aa'"
        storage.expects(:run).in_sequence(s).with(
          "rsync --archive --opt1 --compress " +
          "--password-file='#{ File.expand_path('my/pwd_file') }' " +
          %Q[-e "ssh -p 123 -l ssh_username -i '/my/id_rsa'" ] +
          "'#{ package_files[0] }' #{ dest }"
        )

        # Second Package File
        dest = "rsync_username@host.name::'backups/test_trigger.tar-ab'"
        storage.expects(:run).in_sequence(s).with(
          "rsync --archive --opt1 --compress " +
          "--password-file='#{ File.expand_path('my/pwd_file') }' " +
          %Q[-e "ssh -p 123 -l ssh_username -i '/my/id_rsa'" ] +
          "'#{ package_files[1] }' #{ dest }"
        )

        storage.send(:transfer!)
      end
    end # context 'remote transfer in :ssh_daemon mode'

    context 'remote transfer in :rsync_daemon mode' do
      it 'performs the transfer' do
        storage = Storage::RSync.new(model) do |rsync|
          rsync.mode = :rsync_daemon
          rsync.host = 'host.name'
          rsync.path = 'module/path'
        end

        # write_password_file does nothing
        Tempfile.expects(:new).never

        # create_remote_path does nothing

        # First Package File
        dest = "host.name::'module/path/test_trigger.tar-aa'"
        storage.expects(:run).in_sequence(s).with(
          "rsync --archive --port 873 '#{ package_files[0] }' #{ dest }"
        )

        # Second Package File
        dest = "host.name::'module/path/test_trigger.tar-ab'"
        storage.expects(:run).in_sequence(s).with(
          "rsync --archive --port 873 '#{ package_files[1] }' #{ dest }"
        )

        storage.send(:transfer!)
      end

      it 'uses additional options, with password' do
        storage = Storage::RSync.new(model) do |rsync|
          rsync.mode = :rsync_daemon
          rsync.host = 'host.name'
          rsync.port = 123
          rsync.rsync_user = 'rsync_username'
          rsync.rsync_password = 'secret'
          rsync.compress = true
          rsync.additional_rsync_options = '--opt1'
        end

        # write_password_file
        password_file = stub(:path => '/path/to/password_file')
        Tempfile.expects(:new).in_sequence(s).
            with('backup-rsync-password').returns(password_file)
        password_file.expects(:write).in_sequence(s).with('secret')
        password_file.expects(:close).in_sequence(s)

        # create_remote_path does nothing

        # First Package File
        dest = "rsync_username@host.name::'backups/test_trigger.tar-aa'"
        storage.expects(:run).in_sequence(s).with(
          "rsync --archive --opt1 --compress " +
          "--password-file='/path/to/password_file' --port 123 " +
          "'#{ package_files[0] }' #{ dest }"
        )

        # Second Package File
        dest = "rsync_username@host.name::'backups/test_trigger.tar-ab'"
        storage.expects(:run).in_sequence(s).with(
          "rsync --archive --opt1 --compress " +
          "--password-file='/path/to/password_file' --port 123 " +
          "'#{ package_files[1] }' #{ dest }"
        )

        # remove_password_file!
        password_file.expects(:delete).in_sequence(s)

        storage.send(:transfer!)
      end

      it 'ensures temporary password file is removed' do
        storage = Storage::RSync.new(model) do |rsync|
          rsync.mode = :rsync_daemon
          rsync.host = 'host.name'
          rsync.rsync_password = 'secret'
        end

        # write_password_file
        password_file = stub(:path => '/path/to/password_file')
        Tempfile.expects(:new).in_sequence(s).
            with('backup-rsync-password').returns(password_file)
        password_file.expects(:write).in_sequence(s).with('secret')
        password_file.expects(:close).in_sequence(s)

        # create_remote_path does nothing

        # First Package File (fails)
        dest = "host.name::'backups/test_trigger.tar-aa'"
        storage.expects(:run).in_sequence(s).with(
          "rsync --archive " +
          "--password-file='/path/to/password_file' --port 873 " +
          "'#{ package_files[0] }' #{ dest }"
        ).raises('an error')

        # remove_password_file
        password_file.expects(:delete).in_sequence(s)

        expect do
          storage.send(:transfer!)
        end.to raise_error('an error')
      end

      it 'uses additional options, with password_file' do
        storage = Storage::RSync.new(model) do |rsync|
          rsync.mode = :rsync_daemon
          rsync.host = 'host.name'
          rsync.port = 123
          rsync.rsync_user = 'rsync_username'
          rsync.rsync_password_file = 'my/pwd_file'
          rsync.compress = true
          rsync.additional_rsync_options = '--opt1'
        end

        # write_password_file does nothing
        Tempfile.expects(:new).never

        # create_remote_path does nothing

        # First Package File
        dest = "rsync_username@host.name::'backups/test_trigger.tar-aa'"
        storage.expects(:run).in_sequence(s).with(
          "rsync --archive --opt1 --compress " +
          "--password-file='#{ File.expand_path('my/pwd_file') }' --port 123 " +
          "'#{ package_files[0] }' #{ dest }"
        )

        # Second Package File
        dest = "rsync_username@host.name::'backups/test_trigger.tar-ab'"
        storage.expects(:run).in_sequence(s).with(
          "rsync --archive --opt1 --compress " +
          "--password-file='#{ File.expand_path('my/pwd_file') }' --port 123 " +
          "'#{ package_files[1] }' #{ dest }"
        )

        storage.send(:transfer!)
      end
    end # context 'remote transfer in :rsync_daemon mode'

  end # describe '#perform!'

  describe 'deprecations' do

    describe '#local' do
      before do
        Logger.expects(:warn).with {|err|
          expect( err ).to be_an_instance_of Configuration::Error
          expect( err.message ).to match(
            /If 'host' is not set, the operation will be local/
          )
        }
      end

      context 'when set directly' do
        it 'warns setting is no longer needed' do
          Storage::RSync.new(model) do |s|
            s.local = true
          end
        end
      end

      context 'when set using defaults' do
        after { Storage::RSync.clear_defaults! }

        it 'warns setting is no longer needed' do
          Storage::RSync.defaults do |s|
            s.local = true
          end
          Storage::RSync.new(model)
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
          storage = Storage::RSync.new(model) do |s|
            s.username = 'user_name'
          end
          expect( storage.ssh_user ).to eq 'user_name'
        end
      end

      context 'when set using defaults' do
        after { Storage::RSync.clear_defaults! }

        it 'warns and transfers option value' do
          Storage::RSync.defaults do |s|
            s.username = 'default_user'
          end
          storage = Storage::RSync.new(model)
          expect( storage.ssh_user ).to eq 'default_user'
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
          storage = Storage::RSync.new(model) do |s|
            s.password = 'secret'
          end
          expect( storage.rsync_password ).to eq 'secret'
        end
      end

      context 'when set using defaults' do
        after { Storage::RSync.clear_defaults! }

        it 'warns and transfers option value' do
          Storage::RSync.defaults do |s|
            s.password = 'default_secret'
          end
          storage = Storage::RSync.new(model)
          expect( storage.rsync_password ).to eq 'default_secret'
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
          storage = Storage::RSync.new(model) do |s|
            s.ip = 'hostname'
          end
          expect( storage.host ).to eq 'hostname'
        end
      end

      context 'when set using defaults' do
        after { Storage::RSync.clear_defaults! }

        it 'warns and transfers option value' do
          Storage::RSync.defaults do |s|
            s.ip = 'hostname'
          end
          storage = Storage::RSync.new(model)
          expect( storage.host ).to eq 'hostname'
        end
      end
    end # describe '#ip'

  end # describe 'deprecations'
end
end
