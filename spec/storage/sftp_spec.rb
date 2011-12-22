# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::SFTP do

  let(:sftp) do
    Backup::Storage::SFTP.new do |sftp|
      sftp.username  = 'my_username'
      sftp.password  = 'my_password'
      sftp.ip        = '123.45.678.90'
      sftp.port      = 22
      sftp.path      = '~/backups/'
      sftp.keep      = 20
    end
  end

  before do
    Backup::Configuration::Storage::SFTP.clear_defaults!
  end

  it 'should have defined the configuration properly' do
    sftp.username.should == 'my_username'
    sftp.password.should == 'my_password'
    sftp.ip.should       == '123.45.678.90'
    sftp.port.should     == 22
    sftp.path.should     == 'backups/'
    sftp.keep.should     == 20
  end

  it 'should use the defaults if a particular attribute has not been defined' do
    Backup::Configuration::Storage::SFTP.defaults do |sftp|
      sftp.username = 'my_default_username'
      sftp.password = 'my_default_password'
      sftp.path     = '~/backups'
    end

    sftp = Backup::Storage::SFTP.new do |sftp|
      sftp.password = 'my_password'
      sftp.ip       = '123.45.678.90'
    end

    sftp.username.should == 'my_default_username'
    sftp.password.should == 'my_password'
    sftp.ip.should       == '123.45.678.90'
    sftp.port.should     == 22
  end

  it 'should have its own defaults' do
    sftp = Backup::Storage::SFTP.new
    sftp.port.should == 22
    sftp.path.should == 'backups'
  end

  describe '#perform' do
    it 'should invoke transfer! and cycle!' do
      sftp.expects(:transfer!)
      sftp.expects(:cycle!)
      sftp.perform!
    end
  end

  describe '#connection' do
    it 'should establish a connection to the remote server' do
      connection = mock
      Net::SFTP.expects(:start).with(
        '123.45.678.90',
        'my_username',
        :password  => 'my_password',
        :port      => 22
      ).yields(connection)

      sftp.send(:connection) do |conn|
        conn.should be connection
      end
    end
  end # describe '#connection'

  describe '#transfer!' do
    let(:connection) { mock }

    before do
      sftp.stubs(:storage_name).returns('Storage::SFTP')
    end

    context 'when file chunking is not used' do
      it 'should create remote paths and transfer using a single connection' do
        local_file  = "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar"
        remote_file = "#{ Backup::TRIGGER }.tar"

        sftp.expects(:connection).yields(connection)
        sftp.expects(:create_remote_directories).with(connection)

        Backup::Logger.expects(:message).with(
          "Storage::SFTP started transferring '#{local_file}' to '#{sftp.ip}'."
        )

        connection.expects(:upload!).with(
          File.join(Backup::TMP_PATH, local_file),
          File.join('backups/myapp', Backup::TIME, remote_file)
        )

        sftp.send(:transfer!)
      end
    end

    context 'when file chunking is used' do
      it 'should transfer all the provided files using a single connection' do
        s = sequence ''

        sftp.expects(:connection).in_sequence(s).yields(connection)
        sftp.expects(:create_remote_directories).in_sequence(s).with(connection)

        sftp.expects(:files_to_transfer).in_sequence(s).multiple_yields(
          ['local_file1', 'remote_file1'], ['local_file2', 'remote_file2']
        )

        Backup::Logger.expects(:message).in_sequence(s).with(
          "Storage::SFTP started transferring 'local_file1' to '#{sftp.ip}'."
        )
        connection.expects(:upload!).in_sequence(s).with(
          File.join(Backup::TMP_PATH, 'local_file1'),
          File.join('backups/myapp', Backup::TIME, 'remote_file1')
        )

        Backup::Logger.expects(:message).in_sequence(s).with(
          "Storage::SFTP started transferring 'local_file2' to '#{sftp.ip}'."
        )
        connection.expects(:upload!).in_sequence(s).with(
          File.join(Backup::TMP_PATH, 'local_file2'),
          File.join('backups/myapp', Backup::TIME, 'remote_file2')
        )

        sftp.send(:transfer!)
      end
    end
  end # describe '#transfer'

  describe '#remove!' do
    it 'should remove all remote files with a single FTP connection' do
      s = sequence ''
      connection = mock
      remote_path = "backups/myapp/#{ Backup::TIME }"
      sftp.stubs(:storage_name).returns('Storage::SFTP')

      sftp.expects(:connection).in_sequence(s).yields(connection)

      sftp.expects(:transferred_files).in_sequence(s).multiple_yields(
        ['local_file1', 'remote_file1'], ['local_file2', 'remote_file2']
      )

      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::SFTP started removing 'local_file1' from '#{sftp.ip}'."
      )
      connection.expects(:remove!).in_sequence(s).with(
        File.join(remote_path, 'remote_file1')
      )

      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::SFTP started removing 'local_file2' from '#{sftp.ip}'."
      )
      connection.expects(:remove!).in_sequence(s).with(
        File.join(remote_path, 'remote_file2')
      )

      connection.expects(:rmdir!).in_sequence(s).with(remote_path)

      sftp.send(:remove!)
    end
  end # describe '#remove!'

  describe '#create_remote_directories' do
    let(:connection) { mock }

    context 'while properly creating remote directories one by one' do
      it 'should rescue any SFTP::StatusExceptions' do
        s = sequence ''
        sftp.path = '~/backups/some_other_folder/another_folder'
        sftp_response = stub(:code => 11, :message => nil)
        sftp_status_exception = Net::SFTP::StatusException.new(sftp_response)

        connection.expects(:mkdir!).in_sequence(s).
            with("~").raises(sftp_status_exception)
        connection.expects(:mkdir!).in_sequence(s).
            with("~/backups").raises(sftp_status_exception)
        connection.expects(:mkdir!).in_sequence(s).
            with("~/backups/some_other_folder")
        connection.expects(:mkdir!).in_sequence(s).
            with("~/backups/some_other_folder/another_folder")
        connection.expects(:mkdir!).in_sequence(s).
            with("~/backups/some_other_folder/another_folder/myapp")
        connection.expects(:mkdir!).in_sequence(s).
            with("~/backups/some_other_folder/another_folder/myapp/#{ Backup::TIME }")

        expect do
          sftp.send(:create_remote_directories, connection)
        end.not_to raise_error
      end
    end
  end

end
