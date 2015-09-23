# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Storage::FTP do
  let(:model)   { Model.new(:test_trigger, 'test label') }
  let(:storage) { Storage::FTP.new(model) }
  let(:s) { sequence '' }

  it_behaves_like 'a class that includes Config::Helpers'
  it_behaves_like 'a subclass of Storage::Base'
  it_behaves_like 'a storage that cycles'

  describe '#initialize' do

    it 'provides default values' do
      expect( storage.storage_id    ).to be_nil
      expect( storage.keep          ).to be_nil
      expect( storage.username      ).to be_nil
      expect( storage.password      ).to be_nil
      expect( storage.ip            ).to be_nil
      expect( storage.port          ).to be 21
      expect( storage.passive_mode  ).to be false
      expect( storage.timeout       ).to be nil
      expect( storage.path          ).to eq 'backups'
    end

    it 'configures the storage' do
      storage = Storage::FTP.new(model, :my_id) do |ftp|
        ftp.keep = 2
        ftp.username      = 'my_username'
        ftp.password      = 'my_password'
        ftp.ip            = 'my_host'
        ftp.port          = 123
        ftp.passive_mode  = true
        ftp.timeout       = 10
        ftp.path          = 'my/path'
      end

      expect( storage.storage_id    ).to eq 'my_id'
      expect( storage.keep          ).to be 2
      expect( storage.username      ).to eq 'my_username'
      expect( storage.password      ).to eq 'my_password'
      expect( storage.ip            ).to eq 'my_host'
      expect( storage.port          ).to be 123
      expect( storage.passive_mode  ).to be true
      expect( storage.timeout       ).to be 10
      expect( storage.path          ).to eq 'my/path'
    end

    it 'converts a tilde path to a relative path' do
      storage = Storage::FTP.new(model) do |scp|
        scp.path = '~/my/path'
      end
      expect( storage.path ).to eq 'my/path'
    end

    it 'does not alter an absolute path' do
      storage = Storage::FTP.new(model) do |scp|
        scp.path = '/my/path'
      end
      expect( storage.path ).to eq '/my/path'
    end

  end # describe '#initialize'

  describe '#connection' do
    let(:connection) { mock }

    before do
      @ftp_port = Net::FTP::FTP_PORT
      storage.ip = '123.45.678.90'
      storage.username = 'my_user'
      storage.password = 'my_pass'
    end

    after do
      Net::FTP.send(:remove_const, :FTP_PORT)
      Net::FTP.send(:const_set, :FTP_PORT, @ftp_port)
    end

    it 'yields a connection to the remote server' do
      Net::FTP.expects(:open).with(
        '123.45.678.90', 'my_user', 'my_pass'
      ).yields(connection)

      storage.send(:connection) do |ftp|
        expect( ftp ).to be connection
      end
    end

    it 'sets the FTP_PORT' do
      storage = Storage::FTP.new(model) do |ftp|
        ftp.port = 123
      end
      Net::FTP.stubs(:open)

      storage.send(:connection)
      expect( Net::FTP::FTP_PORT ).to be 123
    end

    # there's no way to really test this without making a connection,
    # since an error will be raised if no connection can be made.
    it 'sets passive mode true if specified' do
      storage.passive_mode = true

      Net::FTP.expects(:open).with(
        '123.45.678.90', 'my_user', 'my_pass'
      ).yields(connection)

      connection.expects(:passive=).with(true)

      storage.send(:connection) {}
    end

    it 'sets timeout if specified' do
      storage.timeout = 10

      Net::FTP.expects(:open).with(
        '123.45.678.90', 'my_user', 'my_pass'
      ).yields(connection)

      connection.expects(:open_timeout=).with(10)
      connection.expects(:read_timeout=).with(10)

      storage.send(:connection) {}
    end

  end # describe '#connection'

  describe '#transfer!' do
    let(:connection) { mock }
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) { File.join('my/path/test_trigger', timestamp) }

    before do
      Timecop.freeze
      storage.package.time = timestamp
      storage.package.stubs(:filenames).returns(
        ['test_trigger.tar-aa', 'test_trigger.tar-ab']
      )
      storage.ip = '123.45.678.90'
      storage.path = 'my/path'
    end

    after { Timecop.return }

    it 'transfers the package files' do
      storage.expects(:connection).in_sequence(s).yields(connection)

      storage.expects(:create_remote_path).in_sequence(s).with(connection)

      src = File.join(Config.tmp_path, 'test_trigger.tar-aa')
      dest = File.join(remote_path, 'test_trigger.tar-aa')

      Logger.expects(:info).in_sequence(s).
          with("Storing '123.45.678.90:#{ dest }'...")

      connection.expects(:put).in_sequence(s).with(src, dest)

      src = File.join(Config.tmp_path, 'test_trigger.tar-ab')
      dest = File.join(remote_path, 'test_trigger.tar-ab')

      Logger.expects(:info).in_sequence(s).
          with("Storing '123.45.678.90:#{ dest }'...")

      connection.expects(:put).in_sequence(s).with(src, dest)

      storage.send(:transfer!)
    end
  end # describe '#transfer!'

  describe '#remove!' do
    let(:connection) { mock }
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) { File.join('my/path/test_trigger', timestamp) }
    let(:package) {
      stub( # loaded from YAML storage file
        :trigger    => 'test_trigger',
        :time       => timestamp,
        :filenames  => ['test_trigger.tar-aa', 'test_trigger.tar-ab']
      )
    }

    before do
      Timecop.freeze
      storage.path = 'my/path'
    end

    after { Timecop.return }

    it 'removes the given package from the remote' do
      Logger.expects(:info).in_sequence(s).
          with("Removing backup package dated #{ timestamp }...")

      storage.expects(:connection).in_sequence(s).yields(connection)

      target = File.join(remote_path, 'test_trigger.tar-aa')
      connection.expects(:delete).in_sequence(s).with(target)

      target = File.join(remote_path, 'test_trigger.tar-ab')
      connection.expects(:delete).in_sequence(s).with(target)

      connection.expects(:rmdir).in_sequence(s).with(remote_path)

      storage.send(:remove!, package)
    end
  end # describe '#remove!'

  describe '#create_remote_path' do
    let(:connection)  { mock }
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) { File.join('my/path/test_trigger', timestamp) }

    before do
      Timecop.freeze
      storage.package.time = timestamp
      storage.path = 'my/path'
    end

    after { Timecop.return }

    context 'while properly creating remote directories one by one' do
      it 'should rescue any SFTP::StatusException and continue' do
        connection.expects(:mkdir).in_sequence(s).
            with("my")
        connection.expects(:mkdir).in_sequence(s).
            with("my/path").raises(Net::FTPPermError)
        connection.expects(:mkdir).in_sequence(s).
            with("my/path/test_trigger")
        connection.expects(:mkdir).in_sequence(s).
            with("my/path/test_trigger/#{ timestamp }")

        expect do
          storage.send(:create_remote_path, connection)
        end.not_to raise_error
      end
    end
  end # describe '#create_remote_path'


end
end
