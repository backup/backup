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

  it 'should be a subclass of Storage::Base' do
    Backup::Storage::SFTP.
      superclass.should == Backup::Storage::Base
  end

  describe '#initialize' do
    after { Backup::Storage::SFTP.clear_defaults! }

    it 'should load pre-configured defaults through Base' do
      Backup::Storage::SFTP.any_instance.expects(:load_defaults!)
      storage
    end

    it 'should pass the model reference to Base' do
      storage.instance_variable_get(:@model).should == model
    end

    it 'should pass the storage_id to Base' do
      storage = Backup::Storage::SFTP.new(model, 'my_storage_id')
      storage.storage_id.should == 'my_storage_id'
    end

    it 'should remove any preceeding tilde and slash from the path' do
      storage = Backup::Storage::SFTP.new(model) do |sftp|
        sftp.path = '~/my_backups/path'
      end
      storage.path.should == 'my_backups/path'
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        storage.username.should == 'my_username'
        storage.password.should == 'my_password'
        storage.ip.should       == '123.45.678.90'
        storage.port.should     == 22
        storage.path.should     == 'backups'

        storage.storage_id.should be_nil
        storage.keep.should       == 5
      end

      it 'should use default values if none are given' do
        storage = Backup::Storage::SFTP.new(model)

        storage.username.should be_nil
        storage.password.should be_nil
        storage.ip.should       be_nil
        storage.port.should     == 22
        storage.path.should     == 'backups'

        storage.storage_id.should be_nil
        storage.keep.should       be_nil
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Storage::SFTP.defaults do |s|
          s.username  = 'some_username'
          s.password  = 'some_password'
          s.ip        = 'some_ip'
          s.port      = 'some_port'
          s.path      = 'some_path'
          s.keep      = 'some_keep'
        end
      end

      it 'should use pre-configured defaults' do
        storage = Backup::Storage::SFTP.new(model)

        storage.username.should == 'some_username'
        storage.password.should == 'some_password'
        storage.ip.should       == 'some_ip'
        storage.port.should     == 'some_port'
        storage.path.should     == 'some_path'

        storage.storage_id.should be_nil
        storage.keep.should       == 'some_keep'
      end

      it 'should override pre-configured defaults' do
        storage = Backup::Storage::SFTP.new(model) do |s|
          s.username  = 'new_username'
          s.password  = 'new_password'
          s.ip        = 'new_ip'
          s.port      = 'new_port'
          s.path      = 'new_path'
          s.keep      = 'new_keep'
        end

        storage.username.should == 'new_username'
        storage.password.should == 'new_password'
        storage.ip.should       == 'new_ip'
        storage.port.should     == 'new_port'
        storage.path.should     == 'new_path'

        storage.storage_id.should be_nil
        storage.keep.should       == 'new_keep'
      end
    end # context 'when pre-configured defaults have been set'
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
      Backup::Logger.expects(:info).in_sequence(s).with(
        "Storage::SFTP started transferring " +
        "'2011.12.31.11.00.02.backup.tar.enc-aa' to '123.45.678.90'."
      )
      connection.expects(:upload!).in_sequence(s).with(
        File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-aa'),
        File.join('remote/path', 'backup.tar.enc-aa')
      )
      # second yield
      Backup::Logger.expects(:info).in_sequence(s).with(
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
      Backup::Logger.expects(:info).in_sequence(s).with(
        "Storage::SFTP started removing " +
        "'2011.12.31.11.00.02.backup.tar.enc-aa' from '123.45.678.90'."
      )
      connection.expects(:remove!).in_sequence(s).with(
        File.join('remote/path', 'backup.tar.enc-aa')
      )
      # second yield
      Backup::Logger.expects(:info).in_sequence(s).with(
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
