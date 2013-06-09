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

end
end