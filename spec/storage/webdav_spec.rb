# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Storage::Webdav do
  let(:model)   { Model.new(:test_trigger, 'test label') }
  let(:storage) { Storage::Webdav.new(model) }

  it_behaves_like 'a class that includes Config::Helpers'
  it_behaves_like 'a subclass of Storage::Base'
  it_behaves_like 'a storage that cycles'

  describe '#initialize' do
    it 'provides default values' do
      expect(storage.storage_id).to be_nil
      expect(storage.keep      ).to be_nil
      expect(storage.username  ).to be_nil
      expect(storage.password  ).to be_nil
      expect(storage.ip        ).to be_nil
      expect(storage.port      ).to eq 80
      expect(storage.use_ssl   ).to eq false
      expect(storage.ssl_verify).to eq true
      expect(storage.timeout   ).to be_nil
      expect(storage.path      ).to eq 'backups'
    end

    it 'configures the storage' do
      storage = Storage::Webdav.new(model, :my_id) do |webdav|
        webdav.keep = 2
        webdav.username      = 'my_username'
        webdav.password      = 'my_password'
        webdav.ip            = 'my_host'
        webdav.port          = 123
        webdav.use_ssl       = true
        webdav.ssl_verify    = false
        webdav.timeout       = 10
        webdav.path          = 'my/path'
      end

      expect( storage.storage_id    ).to eq 'my_id'
      expect( storage.keep          ).to be 2
      expect( storage.username      ).to eq 'my_username'
      expect( storage.password      ).to eq 'my_password'
      expect( storage.ip            ).to eq 'my_host'
      expect( storage.port          ).to be 123
      expect( storage.use_ssl       ).to eq true
      expect( storage.ssl_verify    ).to eq false
      expect( storage.timeout       ).to be 10
      expect( storage.path          ).to eq 'my/path'
    end

    it 'converts a tilde path to a relative path' do
      storage = Storage::Webdav.new(model) do |sftp|
        sftp.path = '~/my/path'
      end
      expect( storage.path ).to eq 'my/path'
    end

    it 'does not alter an absolute path' do
      storage = Storage::Webdav.new(model) do |sftp|
        sftp.path = '/my/path'
      end
      expect( storage.path ).to eq '/my/path'
    end
  end # describe '#initialize'

  describe '#connection' do
    let(:connection) { mock }

    before do
      storage.ip = 'example.com'
      storage.port = 443
      storage.use_ssl = true
      storage.username = 'my_user'
      storage.password = 'my_pass'
    end

    it 'returns a connection' do
      storage.expects(:connection).returns(connection)
      expect(storage.send(:connection)).to eq connection
    end
  end # describe '#connection'

  describe '#create_remote_path' do
    let(:connection) { mock }
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) { File.join('my/long/path/test_trigger', timestamp) }

    before do
      storage.package.time = timestamp
      storage.ip = 'example.com'
      storage.path = 'my/long/path'
    end

    it 'creates the collection on the server' do
      storage.expects(:connection).at_least(4).returns(connection)
      connection.expects(:run_request).with(:mkcol, 'my', nil, nil)
      connection.expects(:run_request).with(:mkcol, 'my/long', nil, nil)
      connection.expects(:run_request).with(:mkcol, 'my/long/path', nil, nil)
      connection.expects(:run_request).with(:mkcol, 'my/long/path/test_trigger', nil, nil)
      connection.expects(:run_request).with(:mkcol, 'my/long/path/test_trigger/'+timestamp, nil, nil)
      storage.send(:create_remote_path)
    end
  end # describe '#create_remote_path'

  describe '#transfer!' do
    let(:connection) { mock }
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) { File.join('my/path/test_trigger', timestamp) }

    before do
      storage.package.time = timestamp
      storage.package.stubs(:filenames).returns(
        ['test_trigger.tar-aa', 'test_trigger.tar-ab']
      )

      storage.ip = 'example.com'
      storage.username = 'my_user'
      storage.password = 'my_pass'
      storage.path = 'my/path'
    end

    it 'transfers the package files' do
      storage.expects(:connection).times(2).returns(connection)
      storage.expects(:create_remote_path)

      dest = File.join(remote_path, 'test_trigger.tar-aa')
      connection.expects(:put).with(dest)
      Logger.expects(:info).with("Storing 'example.com:#{ dest }'...")

      dest = File.join(remote_path, 'test_trigger.tar-ab')
      connection.expects(:put).with(dest)
      Logger.expects(:info).with("Storing 'example.com:#{ dest }'...")

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
      storage.path = 'my/path'
    end

    it 'removes the given package from the remote' do
      Logger.expects(:info).with("Removing backup package dated #{timestamp}...")
      storage.expects(:connection).at_least(2).returns(connection)

      target = File.join(remote_path, 'test_trigger.tar-aa')
      connection.expects(:delete).with(target)

      target = File.join(remote_path, 'test_trigger.tar-ab')
      connection.expects(:delete).with(target)

      connection.expects(:delete).with(remote_path+'/')

      storage.send(:remove!, package)
    end
  end # describe '#remove!'
end
end
