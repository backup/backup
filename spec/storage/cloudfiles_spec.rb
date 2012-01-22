# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::CloudFiles do
  let(:model)   { Backup::Model.new(:test_trigger, 'test label') }
  let(:storage) do
    Backup::Storage::CloudFiles.new(model) do |cf|
      cf.username  = 'my_username'
      cf.api_key   = 'my_api_key'
      cf.auth_url  = 'lon.auth.api.rackspacecloud.com'
      cf.container = 'my_container'
      cf.keep      = 5
    end
  end

  describe '#initialize' do
    it 'should set the correct values' do
      storage.username.should   == 'my_username'
      storage.api_key.should    == 'my_api_key'
      storage.auth_url.should   == 'lon.auth.api.rackspacecloud.com'
      storage.container.should  == 'my_container'
      storage.servicenet.should == false
      storage.path.should       == 'backups'

      storage.storage_id.should be_nil
      storage.keep.should       == 5
    end

    it 'should set a storage_id if given' do
      cf = Backup::Storage::CloudFiles.new(model, 'my storage_id')
      cf.storage_id.should == 'my storage_id'
    end

    context 'when setting configuration defaults' do
      after { Backup::Configuration::Storage::CloudFiles.clear_defaults! }

      it 'should use the configured defaults' do
        Backup::Configuration::Storage::CloudFiles.defaults do |cf|
          cf.username   = 'some_username'
          cf.api_key    = 'some_api_key'
          cf.auth_url   = 'some_auth_url'
          cf.container  = 'some_container'
          cf.servicenet = true
          cf.path       = 'some_path'
          cf.keep       = 15
        end
        storage = Backup::Storage::CloudFiles.new(model)
        storage.username.should   == 'some_username'
        storage.api_key.should    == 'some_api_key'
        storage.auth_url.should   == 'some_auth_url'
        storage.container.should  == 'some_container'
        storage.servicenet.should == true
        storage.path.should       == 'some_path'

        storage.storage_id.should be_nil
        storage.keep.should       == 15
      end

      it 'should override the configured defaults' do
        Backup::Configuration::Storage::CloudFiles.defaults do |cf|
          cf.username   = 'old_username'
          cf.api_key    = 'old_api_key'
          cf.auth_url   = 'old_auth_url'
          cf.container  = 'old_container'
          cf.servicenet = true
          cf.path       = 'old_path'
          cf.keep       = 15
        end
        storage = Backup::Storage::CloudFiles.new(model) do |cf|
          cf.username   = 'new_username'
          cf.api_key    = 'new_api_key'
          cf.auth_url   = 'new_auth_url'
          cf.container  = 'new_container'
          cf.servicenet = false
          cf.path       = 'new_path'
          cf.keep       = 10
        end

        storage.username.should   == 'new_username'
        storage.api_key.should    == 'new_api_key'
        storage.auth_url.should   == 'new_auth_url'
        storage.container.should  == 'new_container'
        storage.servicenet.should == false
        storage.path.should       == 'new_path'

        storage.storage_id.should be_nil
        storage.keep.should       == 10
      end
    end # context 'when setting configuration defaults'

  end # describe '#initialize'

  describe '#provider' do
    it 'should set the Fog provider' do
      storage.send(:provider).should == 'Rackspace'
    end
  end

  describe '#connection' do
    let(:connection) { mock }

    context 'when @servicenet is set to false' do
      it 'should create a new standard connection' do
        Fog::Storage.expects(:new).once.with(
          :provider             => 'Rackspace',
          :rackspace_username   => 'my_username',
          :rackspace_api_key    => 'my_api_key',
          :rackspace_auth_url   => 'lon.auth.api.rackspacecloud.com',
          :rackspace_servicenet => false
        ).returns(connection)
        storage.send(:connection).should == connection
      end
    end

    context 'when @servicenet is set to true' do
      before do
        storage.servicenet = true
      end

      it 'should create a new servicenet connection' do
        Fog::Storage.expects(:new).once.with(
          :provider             => 'Rackspace',
          :rackspace_username   => 'my_username',
          :rackspace_api_key    => 'my_api_key',
          :rackspace_auth_url   => 'lon.auth.api.rackspacecloud.com',
          :rackspace_servicenet => true
        ).returns(connection)
        storage.send(:connection).should == connection
      end
    end

    it 'should return an existing connection' do
      Fog::Storage.expects(:new).once.returns(connection)
      storage.send(:connection).should == connection
      storage.send(:connection).should == connection
    end

  end # describe '#connection'

  describe '#transfer!' do
    let(:connection) { mock }
    let(:package) { mock }
    let(:file) { mock }
    let(:s) { sequence '' }

    before do
      storage.instance_variable_set(:@package, package)
      storage.stubs(:storage_name).returns('Storage::CloudFiles')
      storage.stubs(:local_path).returns('/local/path')
      storage.stubs(:connection).returns(connection)
    end

    it 'should transfer the package files' do
      storage.expects(:remote_path_for).in_sequence(s).with(package).
          returns('remote/path')
      storage.expects(:files_to_transfer_for).in_sequence(s).with(package).
        multiple_yields(
        ['2011.12.31.11.00.02.backup.tar.enc-aa', 'backup.tar.enc-aa'],
        ['2011.12.31.11.00.02.backup.tar.enc-ab', 'backup.tar.enc-ab']
      )
      # first yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::CloudFiles started transferring " +
        "'2011.12.31.11.00.02.backup.tar.enc-aa'."
      )
      File.expects(:open).in_sequence(s).with(
        File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-aa'), 'r'
      ).yields(file)
      connection.expects(:put_object).in_sequence(s).with(
        'my_container', File.join('remote/path', 'backup.tar.enc-aa'), file
      )
      # second yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::CloudFiles started transferring " +
        "'2011.12.31.11.00.02.backup.tar.enc-ab'."
      )
      File.expects(:open).in_sequence(s).with(
        File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-ab'), 'r'
      ).yields(file)
      connection.expects(:put_object).in_sequence(s).with(
        'my_container', File.join('remote/path', 'backup.tar.enc-ab'), file
      )

      storage.send(:transfer!)
    end
  end # describe '#transfer!'

  describe '#remove!' do
    let(:package) { mock }
    let(:connection) { mock }
    let(:s) { sequence '' }

    before do
      storage.stubs(:storage_name).returns('Storage::CloudFiles')
      storage.stubs(:connection).returns(connection)
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
        "Storage::CloudFiles started removing " +
        "'2011.12.31.11.00.02.backup.tar.enc-aa' " +
        "from container 'my_container'."
      )
      connection.expects(:delete_object).in_sequence(s).with(
        'my_container', File.join('remote/path', 'backup.tar.enc-aa')
      )
      # second yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::CloudFiles started removing " +
        "'2011.12.31.11.00.02.backup.tar.enc-ab' " +
        "from container 'my_container'."
      )
      connection.expects(:delete_object).in_sequence(s).with(
        'my_container', File.join('remote/path', 'backup.tar.enc-ab')
      )

      storage.send(:remove!, package)
    end
  end # describe '#remove!'

end
