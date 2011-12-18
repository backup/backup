# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::FTP do

  let(:ftp) do
    Backup::Storage::FTP.new do |ftp|
      ftp.username     = 'my_username'
      ftp.password     = 'my_password'
      ftp.ip           = '123.45.678.90'
      ftp.port         = 21
      ftp.path         = '~/backups/'
      ftp.keep         = 20
      ftp.passive_mode = false
    end
  end

  before do
    Backup::Configuration::Storage::FTP.clear_defaults!
  end

  it 'should have defined the configuration properly' do
    ftp.username.should     == 'my_username'
    ftp.password.should     == 'my_password'
    ftp.ip.should           == '123.45.678.90'
    ftp.port.should         == 21
    ftp.path.should         == 'backups/'
    ftp.keep.should         == 20
    ftp.passive_mode.should == false
  end

  it 'should use the defaults if a particular attribute has not been defined' do
    Backup::Configuration::Storage::FTP.defaults do |ftp|
      ftp.username = 'my_default_username'
      ftp.password = 'my_default_password'
      ftp.path     = '~/backups'
    end

    ftp = Backup::Storage::FTP.new do |ftp|
      ftp.password = 'my_password'
      ftp.ip       = '123.45.678.90'
    end

    ftp.username.should == 'my_default_username'
    ftp.password.should == 'my_password'
    ftp.ip.should       == '123.45.678.90'
    ftp.port.should     == 21
  end

  it 'should have its own defaults' do
    ftp = Backup::Storage::FTP.new
    ftp.port.should         == 21
    ftp.path.should         == 'backups'
    ftp.passive_mode.should == false
  end

  describe '#perform' do
    it 'should invoke transfer! and cycle!' do
      ftp.expects(:transfer!)
      ftp.expects(:cycle!)
      ftp.perform!
    end
  end

  describe '#connection' do
    let(:connection) { mock }

    it 'should establish a connection to the remote server' do
      Net::FTP.expects(:open).with(
        '123.45.678.90', 'my_username', 'my_password'
      ).yields(connection)

      ftp.send(:connection) do |conn|
        conn.should be connection
      end
    end

    it 'configures net/ftp to use passive mode if passive_mode set to true' do
      ftp.passive_mode = true
      Net::FTP.expects(:open).with(
        '123.45.678.90', 'my_username', 'my_password'
      ).yields(connection)
      connection.expects(:passive=).with(true)

      ftp.send(:connection) do |conn|
        conn.should be connection
      end
    end

    context 'when re-defining the Net::FTP port' do

      def reset_ftp_port
        if defined? Net::FTP::FTP_PORT
          Net::FTP.send(:remove_const, :FTP_PORT)
        end; Net::FTP.send(:const_set, :FTP_PORT, 21)
      end

      before { reset_ftp_port }
      after  { reset_ftp_port }

      it 'should re-define Net::FTP::FTP_PORT' do
        Net::FTP.stubs(:open)
        ftp.port = 40
        ftp.send(:connection)
        Net::FTP::FTP_PORT.should == 40
      end

    end

  end # describe '#connection'

  describe '#transfer!' do
    let(:connection) { mock }

    before do
      ftp.stubs(:storage_name).returns('Storage::FTP')
    end

    context 'when file chunking is not used' do
      it 'should create remote paths and transfer using a single connection' do
        local_file  = "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar"
        remote_file = "#{ Backup::TRIGGER }.tar"

        ftp.expects(:connection).yields(connection)
        ftp.expects(:create_remote_directories).with(connection)

        Backup::Logger.expects(:message).with(
          "Storage::FTP started transferring '#{local_file}' to '#{ftp.ip}'."
        )

        connection.expects(:put).with(
          File.join(Backup::TMP_PATH, local_file),
          File.join('backups/myapp', Backup::TIME, remote_file)
        )

        ftp.send(:transfer!)
      end
    end

    context 'when file chunking is used' do
      it 'should transfer all the provided files using a single connection' do
        s = sequence ''

        ftp.expects(:connection).in_sequence(s).yields(connection)
        ftp.expects(:create_remote_directories).in_sequence(s).with(connection)

        ftp.expects(:files_to_transfer).in_sequence(s).multiple_yields(
          ['local_file1', 'remote_file1'], ['local_file2', 'remote_file2']
        )

        Backup::Logger.expects(:message).in_sequence(s).with(
          "Storage::FTP started transferring 'local_file1' to '#{ftp.ip}'."
        )
        connection.expects(:put).in_sequence(s).with(
          File.join(Backup::TMP_PATH, 'local_file1'),
          File.join('backups/myapp', Backup::TIME, 'remote_file1')
        )

        Backup::Logger.expects(:message).in_sequence(s).with(
          "Storage::FTP started transferring 'local_file2' to '#{ftp.ip}'."
        )
        connection.expects(:put).in_sequence(s).with(
          File.join(Backup::TMP_PATH, 'local_file2'),
          File.join('backups/myapp', Backup::TIME, 'remote_file2')
        )

        ftp.send(:transfer!)
      end
    end
  end # describe '#transfer'

  describe '#remove!' do
    it 'should remove all remote files with a single FTP connection' do
      s = sequence ''
      connection = mock
      remote_path = "backups/myapp/#{ Backup::TIME }"
      ftp.stubs(:storage_name).returns('Storage::FTP')

      ftp.expects(:connection).in_sequence(s).yields(connection)

      ftp.expects(:transferred_files).in_sequence(s).multiple_yields(
        ['local_file1', 'remote_file1'], ['local_file2', 'remote_file2']
      )

      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::FTP started removing 'local_file1' from '#{ftp.ip}'."
      )
      connection.expects(:delete).in_sequence(s).with(
        File.join(remote_path, 'remote_file1')
      )

      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::FTP started removing 'local_file2' from '#{ftp.ip}'."
      )
      connection.expects(:delete).in_sequence(s).with(
        File.join(remote_path, 'remote_file2')
      )

      connection.expects(:rmdir).in_sequence(s).with(remote_path)

      ftp.send(:remove!)
    end
  end # describe '#remove!'

  describe '#create_remote_directories!' do
    let(:connection) { mock }

    context 'while properly creating remote directories one by one' do
      it 'should rescue any FTPPermErrors' do
        s = sequence ''
        ftp.path = '~/backups/some_other_folder/another_folder'

        connection.expects(:mkdir).in_sequence(s).
            with("~").raises(Net::FTPPermError)
        connection.expects(:mkdir).in_sequence(s).
            with("~/backups").raises(Net::FTPPermError)
        connection.expects(:mkdir).in_sequence(s).
            with("~/backups/some_other_folder")
        connection.expects(:mkdir).in_sequence(s).
            with("~/backups/some_other_folder/another_folder")
        connection.expects(:mkdir).in_sequence(s).
            with("~/backups/some_other_folder/another_folder/myapp")
        connection.expects(:mkdir).in_sequence(s).
            with("~/backups/some_other_folder/another_folder/myapp/#{ Backup::TIME }")

        expect do
          ftp.send(:create_remote_directories, connection)
        end.not_to raise_error
      end
    end
  end

end
