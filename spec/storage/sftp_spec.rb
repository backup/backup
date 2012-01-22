# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::SFTP do
  let(:model)   { Backup::Model.new(:test_trigger, 'test label') }
  let(:storage) do
    Backup::Storage::SFTP.new(model) do |sftp|
      sftp.username  = 'my_username'
      sftp.password  = 'my_password'
      sftp.ip        = '123.45.678.90'
      sftp.keep      = 5
    end
  end

  describe '#initialize' do
    it 'should set the correct values' do
      storage.username.should == 'my_username'
      storage.password.should == 'my_password'
      storage.ip.should       == '123.45.678.90'
      storage.port.should     == 22
      storage.path.should     == 'backups'

      storage.storage_id.should be_nil
      storage.keep.should       == 5
    end

    it 'should set a storage_id if given' do
      sftp = Backup::Storage::SFTP.new(model, 'my storage_id')
      sftp.storage_id.should == 'my storage_id'
    end

    it 'should remove any preceeding tilde and slash from the path' do
      storage = Backup::Storage::SFTP.new(model) do |sftp|
        sftp.path = '~/my_backups/path'
      end
      storage.path.should == 'my_backups/path'
    end

    context 'when setting configuration defaults' do
      after { Backup::Configuration::Storage::SFTP.clear_defaults! }

      it 'should use the configured defaults' do
        Backup::Configuration::Storage::SFTP.defaults do |sftp|
          sftp.username  = 'some_username'
          sftp.password  = 'some_password'
          sftp.ip        = 'some_ip'
          sftp.port      = 'some_port'
          sftp.path      = 'some_path'
          sftp.keep      = 'some_keep'
        end
        storage = Backup::Storage::SFTP.new(model)
        storage.username.should == 'some_username'
        storage.password.should == 'some_password'
        storage.ip.should       == 'some_ip'
        storage.port.should     == 'some_port'
        storage.path.should     == 'some_path'

        storage.storage_id.should be_nil
        storage.keep.should       == 'some_keep'
      end

      it 'should override the configured defaults' do
        Backup::Configuration::Storage::SFTP.defaults do |sftp|
          sftp.username  = 'old_username'
          sftp.password  = 'old_password'
          sftp.ip        = 'old_ip'
          sftp.port      = 'old_port'
          sftp.path      = 'old_path'
          sftp.keep      = 'old_keep'
        end
        storage = Backup::Storage::SFTP.new(model) do |sftp|
          sftp.username  = 'new_username'
          sftp.password  = 'new_password'
          sftp.ip        = 'new_ip'
          sftp.port      = 'new_port'
          sftp.path      = 'new_path'
          sftp.keep      = 'new_keep'
        end

        storage.username.should == 'new_username'
        storage.password.should == 'new_password'
        storage.ip.should       == 'new_ip'
        storage.port.should     == 'new_port'
        storage.path.should     == 'new_path'

        storage.storage_id.should be_nil
        storage.keep.should       == 'new_keep'
      end
    end # context 'when setting configuration defaults'

  end # describe '#initialize'

  describe '#connection' do
    let(:connection) { mock }

    it 'should yield a connection to the remote server' do
      Net::SFTP.expects(:start).with(
        '123.45.678.90', 'my_username', :password => 'my_password', :port => 22
      ).yields(connection)

      storage.send(:connection) do |sftp|
        sftp.should be(connection)
      end
    end
  end

  describe '#transfer!' do
    let(:connection) { mock }
    let(:package) { mock }
    let(:s) { sequence '' }

    before do
      storage.instance_variable_set(:@package, package)
      storage.stubs(:storage_name).returns('Storage::SFTP')
      storage.stubs(:local_path).returns('/local/path')
      storage.stubs(:connection).yields(connection)
    end

    it 'should transfer the package files' do
      storage.expects(:remote_path_for).in_sequence(s).with(package).
          returns('remote/path')
      storage.expects(:create_remote_path).in_sequence(s).with(
        'remote/path', connection
      )

      storage.expects(:files_to_transfer_for).in_sequence(s).with(package).
        multiple_yields(
        ['2011.12.31.11.00.02.backup.tar.enc-aa', 'backup.tar.enc-aa'],
        ['2011.12.31.11.00.02.backup.tar.enc-ab', 'backup.tar.enc-ab']
      )
      # first yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::SFTP started transferring " +
        "'2011.12.31.11.00.02.backup.tar.enc-aa' to '123.45.678.90'."
      )
      connection.expects(:upload!).in_sequence(s).with(
        File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-aa'),
        File.join('remote/path', 'backup.tar.enc-aa')
      )
      # second yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::SFTP started transferring " +
        "'2011.12.31.11.00.02.backup.tar.enc-ab' to '123.45.678.90'."
      )
      connection.expects(:upload!).in_sequence(s).with(
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
      storage.stubs(:storage_name).returns('Storage::SFTP')
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
      # first yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::SFTP started removing " +
        "'2011.12.31.11.00.02.backup.tar.enc-aa' from '123.45.678.90'."
      )
      connection.expects(:remove!).in_sequence(s).with(
        File.join('remote/path', 'backup.tar.enc-aa')
      )
      # second yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::SFTP started removing " +
        "'2011.12.31.11.00.02.backup.tar.enc-ab' from '123.45.678.90'."
      )
      connection.expects(:remove!).in_sequence(s).with(
        File.join('remote/path', 'backup.tar.enc-ab')
      )

      connection.expects(:rmdir!).with('remote/path').in_sequence(s)

      storage.send(:remove!, package)
    end
  end # describe '#remove!'

  describe '#create_remote_path' do
    let(:connection)  { mock }
    let(:remote_path) { 'backups/folder/another_folder' }
    let(:s) { sequence '' }
    let(:sftp_response) { stub(:code => 11, :message => nil) }
    let(:sftp_status_exception) { Net::SFTP::StatusException.new(sftp_response) }

    context 'while properly creating remote directories one by one' do
      it 'should rescue any SFTP::StatusException and continue' do
        connection.expects(:mkdir!).in_sequence(s).
            with("backups").raises(sftp_status_exception)
        connection.expects(:mkdir!).in_sequence(s).
            with("backups/folder")
        connection.expects(:mkdir!).in_sequence(s).
            with("backups/folder/another_folder")

        expect do
          storage.send(:create_remote_path, remote_path, connection)
        end.not_to raise_error
      end
    end
  end

end
