# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::SCP do

  let(:scp) do
    Backup::Storage::SCP.new do |scp|
      scp.username  = 'my_username'
      scp.password  = 'my_password'
      scp.ip        = '123.45.678.90'
      scp.port      = 22
      scp.path      = '~/backups/'
      scp.keep      = 20
    end
  end

  before do
    Backup::Configuration::Storage::SCP.clear_defaults!
  end

  it 'should have defined the configuration properly' do
    scp.username.should == 'my_username'
    scp.password.should == 'my_password'
    scp.ip.should       == '123.45.678.90'
    scp.port.should     == 22
    scp.path.should     == 'backups/'
    scp.keep.should     == 20
  end

  it 'should use the defaults if a particular attribute has not been defined' do
    Backup::Configuration::Storage::SCP.defaults do |scp|
      scp.username = 'my_default_username'
      scp.password = 'my_default_password'
      scp.path     = '~/backups'
    end

    scp = Backup::Storage::SCP.new do |scp|
      scp.password = 'my_password'
      scp.ip       = '123.45.678.90'
    end

    scp.username.should == 'my_default_username'
    scp.password.should == 'my_password'
    scp.ip.should       == '123.45.678.90'
    scp.port.should     == 22
  end

  it 'should have its own defaults' do
    scp = Backup::Storage::SCP.new
    scp.port.should == 22
    scp.path.should == 'backups'
  end

  describe '#perform' do
    it 'should invoke transfer! and cycle!' do
      scp.expects(:transfer!)
      scp.expects(:cycle!)
      scp.perform!
    end
  end

  describe '#connection' do
    it 'should establish a connection to the remote server' do
      connection = mock
      Net::SSH.expects(:start).with(
        '123.45.678.90',
        'my_username',
        :password => 'my_password',
        :port => 22
      ).yields(connection)

      scp.send(:connection) do |ssh|
        ssh.should be connection
      end
    end
  end

  describe '#transfer!' do

    before do
      scp.stubs(:storage_name).returns('Storage::SCP')
    end

    context 'when file chunking is not used' do
      it 'should create remote paths and transfer using a single connection' do
        ssh, ssh_scp = mock, mock
        local_file  = "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar"
        remote_file = "#{ Backup::TRIGGER }.tar"

        scp.expects(:connection).yields(ssh)
        scp.expects(:create_remote_directories).with(ssh)

        Backup::Logger.expects(:message).with(
          "Storage::SCP started transferring '#{local_file}' to '#{scp.ip}'."
        )

        ssh.expects(:scp).returns(ssh_scp)
        ssh_scp.expects(:upload!).with(
          File.join(Backup::TMP_PATH, local_file),
          File.join('backups/myapp', Backup::TIME, remote_file)
        )

        scp.send(:transfer!)
      end
    end

    context 'when file chunking is used' do
      it 'should transfer all the provided files using a single connection' do
        s = sequence ''
        ssh, ssh_scp = mock, mock

        scp.expects(:connection).in_sequence(s).yields(ssh)
        scp.expects(:create_remote_directories).in_sequence(s).with(ssh)

        scp.expects(:files_to_transfer).in_sequence(s).multiple_yields(
          ['local_file1', 'remote_file1'], ['local_file2', 'remote_file2']
        )

        Backup::Logger.expects(:message).in_sequence(s).with(
          "Storage::SCP started transferring 'local_file1' to '#{scp.ip}'."
        )
        ssh.expects(:scp).in_sequence(s).returns(ssh_scp)
        ssh_scp.expects(:upload!).in_sequence(s).with(
          File.join(Backup::TMP_PATH, 'local_file1'),
          File.join('backups/myapp', Backup::TIME, 'remote_file1')
        )

        Backup::Logger.expects(:message).in_sequence(s).with(
          "Storage::SCP started transferring 'local_file2' to '#{scp.ip}'."
        )
        ssh.expects(:scp).in_sequence(s).returns(ssh_scp)
        ssh_scp.expects(:upload!).in_sequence(s).with(
          File.join(Backup::TMP_PATH, 'local_file2'),
          File.join('backups/myapp', Backup::TIME, 'remote_file2')
        )

        scp.send(:transfer!)
      end
    end

  end # describe '#transfer!'

  describe '#remove!' do

    before do
      scp.stubs(:storage_name).returns('Storage::SCP')
    end

    it 'should remove all remote files with a single logger call' do
      ssh = mock

      scp.expects(:transferred_files).multiple_yields(
        ['local_file1', 'remote_file1'], ['local_file2', 'remote_file2']
      )

      Backup::Logger.expects(:message).with(
        "Storage::SCP started removing 'local_file1' from '#{scp.ip}'.\n" +
        "Storage::SCP started removing 'local_file2' from '#{scp.ip}'."
      )

      scp.expects(:connection).yields(ssh)
      ssh.expects(:exec!).with("rm -r 'backups/myapp/#{ Backup::TIME }'")

      scp.send(:remove!)
    end

    it 'should raise an error if Net::SSH reports errors' do
      ssh = mock

      scp.expects(:transferred_files)
      Backup::Logger.expects(:message)

      scp.expects(:connection).yields(ssh)
      ssh.expects(:exec!).yields('', :stderr, 'error message')

      expect do
        scp.send(:remove!)
      end.to raise_error(
        Backup::Errors::Storage::SCP::SSHError,
        "Storage::SCP::SSHError: Net::SSH reported the following errors:\n" +
        "  error message"
      )
    end

  end # describe '#remove!'

  describe '#create_remote_directories' do
    it 'should properly create remote directories one by one' do
      ssh = mock
      scp.path = 'backups/some_other_folder/another_folder'

      ssh.expects(:exec!).with("mkdir 'backups'")
      ssh.expects(:exec!).with("mkdir 'backups/some_other_folder'")
      ssh.expects(:exec!).with("mkdir 'backups/some_other_folder/another_folder'")
      ssh.expects(:exec!).with("mkdir 'backups/some_other_folder/another_folder/myapp'")
      ssh.expects(:exec!).with("mkdir 'backups/some_other_folder/another_folder/myapp/#{ Backup::TIME }'")

      scp.send(:create_remote_directories, ssh)
    end
  end

end
