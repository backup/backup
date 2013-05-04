# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Storage::CloudFiles do
  let(:model) { Model.new(:test_trigger, 'test label') }
  let(:storage) { Storage::CloudFiles.new(model) }
  let(:s) { sequence '' }

  it_behaves_like 'a class that includes Configuration::Helpers'
  it_behaves_like 'a subclass of Storage::Base' do
    let(:cycling_supported) { true }
  end

  describe '#initialize' do
    it 'provides default values' do
      expect( storage.storage_id  ).to be_nil
      expect( storage.keep        ).to be_nil
      expect( storage.username    ).to be_nil
      expect( storage.api_key     ).to be_nil
      expect( storage.auth_url    ).to be_nil
      expect( storage.servicenet  ).to be false
      expect( storage.container   ).to be_nil
      expect( storage.path        ).to eq 'backups'
    end

    it 'configures the storage' do
      storage = Storage::CloudFiles.new(model, :my_id) do |cf|
        cf.keep       = 2
        cf.username   = 'my_username'
        cf.api_key    = 'my_api_key'
        cf.auth_url   = 'my_auth_url'
        cf.servicenet = true
        cf.container  = 'my_container'
        cf.path       = 'my/path'
      end

      expect( storage.storage_id  ).to eq 'my_id'
      expect( storage.keep        ).to be 2
      expect( storage.username    ).to eq 'my_username'
      expect( storage.api_key     ).to eq 'my_api_key'
      expect( storage.auth_url    ).to eq 'my_auth_url'
      expect( storage.servicenet  ).to be true
      expect( storage.container   ).to eq 'my_container'
      expect( storage.path        ).to eq 'my/path'
    end

    it 'strips leading path separator' do
      storage = Storage::CloudFiles.new(model) do |cf|
        cf.path = '/this/path'
      end
      expect( storage.path ).to eq 'this/path'
    end

  end # describe '#initialize'

  describe '#connection' do
    let(:connection) { mock }

    before do
      storage.username = 'my_username'
      storage.api_key  = 'my_api_key'
      storage.auth_url = 'my_auth_url'
    end

    context 'when @servicenet is set to false' do
      it 'creates a new standard connection' do
        Fog::Storage.expects(:new).once.with(
          :provider             => 'Rackspace',
          :rackspace_username   => 'my_username',
          :rackspace_api_key    => 'my_api_key',
          :rackspace_auth_url   => 'my_auth_url',
          :rackspace_servicenet => false
        ).returns(connection)
        storage.send(:connection).should == connection
      end
    end

    context 'when @servicenet is set to true' do
      before do
        storage.servicenet = true
      end

      it 'creates a new servicenet connection' do
        Fog::Storage.expects(:new).once.with(
          :provider             => 'Rackspace',
          :rackspace_username   => 'my_username',
          :rackspace_api_key    => 'my_api_key',
          :rackspace_auth_url   => 'my_auth_url',
          :rackspace_servicenet => true
        ).returns(connection)
        storage.send(:connection).should == connection
      end
    end

    it 'caches the connection' do
      Fog::Storage.expects(:new).once.returns(connection)
      expect( storage.send(:connection) ).to eq connection
      expect( storage.send(:connection) ).to eq connection
    end

  end # describe '#connection'

  describe '#transfer!' do
    let(:connection) { mock }
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) { File.join('my/path/test_trigger', timestamp) }
    let(:file) { mock }

    before do
      Timecop.freeze
      storage.package.time = timestamp
      storage.package.stubs(:filenames).returns(
        ['test_trigger.tar-aa', 'test_trigger.tar-ab']
      )
      storage.stubs(:connection).returns(connection)
      storage.container = 'my_container'
      storage.path = 'my/path'
    end

    after { Timecop.return }

    it 'transfers the package files' do
      connection.expects(:put_container).in_sequence(s).with('my_container')

      src = File.join(Config.tmp_path, 'test_trigger.tar-aa')
      dest = File.join(remote_path, 'test_trigger.tar-aa')

      Logger.expects(:info).in_sequence(s).with("Storing 'my_container/#{ dest }'...")
      File.expects(:open).in_sequence(s).with(src, 'r').yields(file)
      connection.expects(:put_object).in_sequence(s).with('my_container', dest, file)

      src = File.join(Config.tmp_path, 'test_trigger.tar-ab')
      dest = File.join(remote_path, 'test_trigger.tar-ab')

      Logger.expects(:info).in_sequence(s).with("Storing 'my_container/#{ dest }'...")
      File.expects(:open).in_sequence(s).with(src, 'r').yields(file)
      connection.expects(:put_object).in_sequence(s).with('my_container', dest, file)

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
      storage.stubs(:connection).returns(connection)
      storage.container = 'my_container'
      storage.path = 'my/path'
    end

    after { Timecop.return }

    it 'removes the given package from the remote' do
      Logger.expects(:info).in_sequence(s).
          with("Removing backup package dated #{ timestamp }...")

      target = File.join(remote_path, 'test_trigger.tar-aa')
      connection.expects(:delete_object).in_sequence(s).with('my_container', target)

      target = File.join(remote_path, 'test_trigger.tar-ab')
      connection.expects(:delete_object).in_sequence(s).with('my_container', target)

      storage.send(:remove!, package)
    end

  end # describe '#remove!'

end
end
