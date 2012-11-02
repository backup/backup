# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

##
# available S3 regions:
# eu-west-1, us-east-1, ap-southeast-1, us-west-1
describe Backup::Storage::Glacier do
  let(:model)   { Backup::Model.new(:test_trigger, 'test label') }
  let(:storage) do
    Backup::Storage::Glacier.new(model) do |glacier|
      glacier.access_key_id      = 'my_access_key_id'
      glacier.secret_access_key  = 'my_secret_access_key'
      glacier.vault              = 'my-vault'
      glacier.region             = 'us-east-1'
      glacier.keep               = 5
    end
  end

  it 'should be a subclass of Storage::Base' do
    Backup::Storage::Glacier.
      superclass.should == Backup::Storage::Base
  end

  describe '#initialize' do
    after { Backup::Storage::Glacier.clear_defaults! }

    it 'should load pre-configured defaults through Base' do
      Backup::Storage::Glacier.any_instance.expects(:load_defaults!)
      storage
    end

    it 'should pass the model reference to Base' do
      storage.instance_variable_get(:@model).should == model
    end

    it 'should pass the storage_id to Base' do
      storage = Backup::Storage::Glacier.new(model, 'my_storage_id')
      storage.storage_id.should == 'my_storage_id'
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        storage.access_key_id.should      == 'my_access_key_id'
        storage.secret_access_key.should  == 'my_secret_access_key'
        storage.vault.should              == 'my-vault'
        #storage.path.should               == 'backups'
        storage.region.should             == 'us-east-1'

        storage.storage_id.should be_nil
        storage.keep.should       == 5
      end

      it 'should use default values if none are given' do
        storage = Backup::Storage::Glacier.new(model)

        storage.access_key_id.should      be_nil
        storage.secret_access_key.should  be_nil
        storage.vault.should              be_nil
        #storage.path.should               == 'backups'
        storage.region.should             be_nil

        storage.storage_id.should be_nil
        storage.keep.should       be_nil
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Storage::Glacier.defaults do |s|
          s.access_key_id      = 'some_access_key_id'
          s.secret_access_key  = 'some_secret_access_key'
          s.vault              = 'some-vault'
          #s.path               = 'some_path'
          s.region             = 'some_region'
          s.keep               = 15
        end
      end

      it 'should use pre-configured defaults' do
        storage = Backup::Storage::Glacier.new(model)

        storage.access_key_id.should      == 'some_access_key_id'
        storage.secret_access_key.should  == 'some_secret_access_key'
        storage.vault.should              == 'some-vault'
        #storage.path.should               == 'some_path'
        storage.region.should             == 'some_region'

        storage.storage_id.should be_nil
        storage.keep.should       == 15
      end

      it 'should override pre-configured defaults' do
        storage = Backup::Storage::Glacier.new(model) do |s|
          s.access_key_id      = 'new_access_key_id'
          s.secret_access_key  = 'new_secret_access_key'
          s.vault              = 'new-vault'
          s.region             = 'new_region'
          s.keep               = 10
        end

        storage.access_key_id.should      == 'new_access_key_id'
        storage.secret_access_key.should  == 'new_secret_access_key'
        storage.vault.should              == 'new-vault'
        #storage.path.should               == 'new_path'
        storage.region.should             == 'new_region'

        storage.storage_id.should be_nil
        storage.keep.should       == 10
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#connection' do
    let(:connection) { mock }

    it 'should create a new connection' do
      Fog::AWS::Glacier.expects(:new).once.with(
        :aws_access_key_id      => 'my_access_key_id',
        :aws_secret_access_key  => 'my_secret_access_key',
        :region                 => 'us-east-1'
      ).returns(connection)
      storage.send(:connection).should == connection
    end

    it 'should return an existing connection' do
      Fog::AWS::Glacier.expects(:new).once.returns(connection)
      storage.send(:connection).should == connection
      storage.send(:connection).should == connection
    end
  end # describe '#connection'

  describe '#transfer!' do
    let(:connection) { mock }
    let(:vaults) { mock }
    let(:vault) { mock }
    let(:archives) { mock }
    let(:archive) { mock }
    let(:package) { mock }
    let(:file) { mock }
    let(:s) { sequence '' }

    before do
      storage.instance_variable_set(:@package, package)
      storage.stubs(:storage_name).returns('Storage::Glacier')
      storage.stubs(:local_path).returns('/local/path')
      storage.stubs(:connection).returns(connection)
      connection.stubs(:vaults).returns(vaults)
      vaults.stubs(:get).returns(vault)
    end

    it 'should transfer the package files' do

      storage.expects(:files_to_transfer_for).in_sequence(s).with(package).
        multiple_yields(
        ['2011.12.31.11.00.02.backup.tar.enc-aa', 'backup.tar.enc-aa'],
        ['2011.12.31.11.00.02.backup.tar.enc-ab', 'backup.tar.enc-ab']
      )
      # first yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::Glacier started transferring " +
        "'2011.12.31.11.00.02.backup.tar.enc-aa' to vault 'my-vault'."
      )
      File.expects(:size).with('/local/path/2011.12.31.11.00.02.backup.tar.enc-aa').returns(524288)
      File.expects(:open).in_sequence(s).with(
        File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-aa'), 'r'
      ).yields(file)
      vault.expects(:archives).returns(archives)
      archives.expects(:create).with(:body => file,
        :description => '2011.12.31.11.00.02.backup.tar.enc-aa',
        :multipart_chunk_size => 1024*1024).returns(archive)

      # second yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::Glacier started transferring " +
        "'2011.12.31.11.00.02.backup.tar.enc-ab' to vault 'my-vault'."
      )
      File.expects(:size).with('/local/path/2011.12.31.11.00.02.backup.tar.enc-ab').returns(1048576)
      File.expects(:open).in_sequence(s).with(
        File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-ab'), 'r'
      ).yields(file)
      vault.expects(:archives).returns(archives)
      archives.expects(:create).with(:body => file,
        :description => '2011.12.31.11.00.02.backup.tar.enc-ab',
        :multipart_chunk_size => 1024*1024).returns(archive)

      storage.send(:transfer!)
    end
  end # describe '#transfer!'

  describe '#remove!' do
    let(:package) { mock }
    let(:connection) { mock }
    let(:s) { sequence '' }

    before do
      storage.stubs(:storage_name).returns('Storage::Glacier')
      storage.stubs(:connection).returns(connection)
    end

    it 'should just trigger a log message hat remove is not supported yet' do
      # first yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::Glacier does not support removing files (yet)"
      )

      storage.send(:remove!, package)
    end
  end # describe '#remove!'

end
