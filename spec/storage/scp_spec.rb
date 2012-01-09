# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::SCP do
  let(:model)   { Backup::Model.new(:test_trigger, 'test label') }
  let(:storage) do
    Backup::Storage::SCP.new(model) do |scp|
      scp.username     = 'my_username'
      scp.password     = 'my_password'
      scp.ip           = '123.45.678.90'
      scp.keep         = 5
    end
  end

  describe '#initialize' do
    it 'should set the correct values' do
      storage.username.should     == 'my_username'
      storage.password.should     == 'my_password'
      storage.ip.should           == '123.45.678.90'
      storage.port.should         == 22
      storage.path.should         == 'backups'

      storage.storage_id.should be_nil
      storage.keep.should       == 5
    end

    it 'should set a storage_id if given' do
      scp = Backup::Storage::SCP.new(model, 'my storage_id')
      scp.storage_id.should == 'my storage_id'
    end

    it 'should remove any preceeding tilde and slash from the path' do
      storage = Backup::Storage::SCP.new(model) do |scp|
        scp.path = '~/my_backups/path'
      end
      storage.path.should == 'my_backups/path'
    end

    context 'when setting configuration defaults' do
      after { Backup::Configuration::Storage::SCP.clear_defaults! }

      it 'should use the configured defaults' do
        Backup::Configuration::Storage::SCP.defaults do |scp|
          scp.username     = 'some_username'
          scp.password     = 'some_password'
          scp.ip           = 'some_ip'
          scp.port         = 'some_port'
          scp.path         = 'some_path'
          scp.keep         = 'some_keep'
        end
        storage = Backup::Storage::SCP.new(model)
        storage.username.should     == 'some_username'
        storage.password.should     == 'some_password'
        storage.ip.should           == 'some_ip'
        storage.port.should         == 'some_port'
        storage.path.should         == 'some_path'

        storage.storage_id.should be_nil
        storage.keep.should       == 'some_keep'
      end

      it 'should override the configured defaults' do
        Backup::Configuration::Storage::SCP.defaults do |scp|
          scp.username     = 'old_username'
          scp.password     = 'old_password'
          scp.ip           = 'old_ip'
          scp.port         = 'old_port'
          scp.path         = 'old_path'
          scp.keep         = 'old_keep'
        end
        storage = Backup::Storage::SCP.new(model) do |scp|
          scp.username     = 'new_username'
          scp.password     = 'new_password'
          scp.ip           = 'new_ip'
          scp.port         = 'new_port'
          scp.path         = 'new_path'
          scp.keep         = 'new_keep'
        end

        storage.username.should     == 'new_username'
        storage.password.should     == 'new_password'
        storage.ip.should           == 'new_ip'
        storage.port.should         == 'new_port'
        storage.path.should         == 'new_path'

        storage.storage_id.should be_nil
        storage.keep.should       == 'new_keep'
      end
    end # context 'when setting configuration defaults'

  end # describe '#initialize'

  describe '#connection' do
    let(:connection) { mock }
    it 'should yield a Net::SSH connection' do
      Net::SSH.expects(:start).with(
        '123.45.678.90', 'my_username', :password => 'my_password', :port => 22
      ).yields(connection)

      storage.send(:connection) do |ssh|
        ssh.should be(connection)
      end
    end
  end

  describe '#transfer!' do
    let(:connection) { mock }
    let(:package) { mock }
    let(:ssh_scp) { mock }
    let(:s) { sequence '' }

    before do
      storage.instance_variable_set(:@package, package)
      storage.stubs(:storage_name).returns('Storage::SCP')
      storage.stubs(:local_path).returns('/local/path')
      storage.stubs(:connection).yields(connection)
      connection.stubs(:scp).returns(ssh_scp)
    end

    it 'should transfer the package files' do
      storage.expects(:remote_path_for).in_sequence(s).with(package).
          returns('remote/path')
      connection.expects(:exec!).in_sequence(s).with("mkdir -p 'remote/path'")

      storage.expects(:files_to_transfer_for).in_sequence(s).with(package).
        multiple_yields(
        ['2011.12.31.11.00.02.backup.tar.enc-aa', 'backup.tar.enc-aa'],
        ['2011.12.31.11.00.02.backup.tar.enc-ab', 'backup.tar.enc-ab']
      )
      # first yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::SCP started transferring " +
        "'2011.12.31.11.00.02.backup.tar.enc-aa' to '123.45.678.90'."
      )
      ssh_scp.expects(:upload!).in_sequence(s).with(
        File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-aa'),
        File.join('remote/path', 'backup.tar.enc-aa')
      )
      # second yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::SCP started transferring " +
        "'2011.12.31.11.00.02.backup.tar.enc-ab' to '123.45.678.90'."
      )
      ssh_scp.expects(:upload!).in_sequence(s).with(
        File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-ab'),
        File.join('remote/path', 'backup.tar.enc-ab')
      )

      storage.send(:transfer!)
    end
  end # describe '#transfer!'

  describe '#remove!' do
    let(:package) { mock }
    let(:connection) { mock }
    let(:s) { sequence '' }

    before do
      storage.stubs(:storage_name).returns('Storage::SCP')
      storage.stubs(:connection).yields(connection)
    end

    it 'should remove the package files' do
      storage.expects(:remote_path_for).in_sequence(s).with(package).
          returns('remote/path')

      storage.expects(:transferred_files_for).in_sequence(s).with(package).
        multiple_yields(
        ['2011.12.31.11.00.02.backup.tar.enc-aa', 'backup.tar.enc-aa'],
        ['2011.12.31.11.00.02.backup.tar.enc-ab', 'backup.tar.enc-ab']
      )
      # after both yields
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::SCP started removing " +
        "'2011.12.31.11.00.02.backup.tar.enc-aa' from '123.45.678.90'.\n" +
        "Storage::SCP started removing " +
        "'2011.12.31.11.00.02.backup.tar.enc-ab' from '123.45.678.90'."
      )
      connection.expects(:exec!).with("rm -r 'remote/path'").in_sequence(s)

      storage.send(:remove!, package)
    end

    context 'when the ssh connection reports errors' do
      it 'should raise an error reporting the errors' do
        storage.expects(:remote_path_for).in_sequence(s).with(package).
            returns('remote/path')

        storage.expects(:transferred_files_for).in_sequence(s).with(package)

        Backup::Logger.expects(:message).in_sequence(s)

        connection.expects(:exec!).with("rm -r 'remote/path'").in_sequence(s).
          yields(:ch, :stderr, 'path not found')

        expect do
          storage.send(:remove!, package)
        end.to raise_error {|err|
          err.should be_an_instance_of Backup::Errors::Storage::SCP::SSHError
          err.message.should == "Storage::SCP::SSHError: " +
            "Net::SSH reported the following errors:\n" +
            "  path not found"
        }
      end
    end
  end # describe '#remove!'

end
