# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

##
# available S3 regions:
# eu-west-1, us-east-1, ap-southeast-1, us-west-1
describe Backup::Storage::S3 do
  let(:model)   { Backup::Model.new(:test_trigger, 'test label') }
  let(:storage) do
    Backup::Storage::S3.new(model) do |s3|
      s3.access_key_id      = 'my_access_key_id'
      s3.secret_access_key  = 'my_secret_access_key'
      s3.bucket             = 'my-bucket'
      s3.region             = 'us-east-1'
      s3.keep               = 5
    end
  end

  it 'should be a subclass of Storage::Base' do
    Backup::Storage::S3.
      superclass.should == Backup::Storage::Base
  end

  describe '#initialize' do
    after { Backup::Storage::S3.clear_defaults! }

    it 'should load pre-configured defaults through Base' do
      Backup::Storage::S3.any_instance.expects(:load_defaults!)
      storage
    end

    it 'should pass the model reference to Base' do
      storage.instance_variable_get(:@model).should == model
    end

    it 'should pass the storage_id to Base' do
      storage = Backup::Storage::S3.new(model, 'my_storage_id')
      storage.storage_id.should == 'my_storage_id'
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        storage.access_key_id.should      == 'my_access_key_id'
        storage.secret_access_key.should  == 'my_secret_access_key'
        storage.bucket.should             == 'my-bucket'
        storage.path.should               == 'backups'
        storage.region.should             == 'us-east-1'

        storage.storage_id.should be_nil
        storage.keep.should       == 5
      end

      it 'should use default values if none are given' do
        storage = Backup::Storage::S3.new(model)

        storage.access_key_id.should      be_nil
        storage.secret_access_key.should  be_nil
        storage.bucket.should             be_nil
        storage.path.should               == 'backups'
        storage.region.should             be_nil

        storage.storage_id.should be_nil
        storage.keep.should       be_nil
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Storage::S3.defaults do |s|
          s.access_key_id      = 'some_access_key_id'
          s.secret_access_key  = 'some_secret_access_key'
          s.bucket             = 'some-bucket'
          s.path               = 'some_path'
          s.region             = 'some_region'
          s.keep               = 15
        end
      end

      it 'should use pre-configured defaults' do
        storage = Backup::Storage::S3.new(model)

        storage.access_key_id.should      == 'some_access_key_id'
        storage.secret_access_key.should  == 'some_secret_access_key'
        storage.bucket.should             == 'some-bucket'
        storage.path.should               == 'some_path'
        storage.region.should             == 'some_region'

        storage.storage_id.should be_nil
        storage.keep.should       == 15
      end

      it 'should override pre-configured defaults' do
        storage = Backup::Storage::S3.new(model) do |s|
          s.access_key_id      = 'new_access_key_id'
          s.secret_access_key  = 'new_secret_access_key'
          s.bucket             = 'new-bucket'
          s.path               = 'new_path'
          s.region             = 'new_region'
          s.keep               = 10
        end

        storage.access_key_id.should      == 'new_access_key_id'
        storage.secret_access_key.should  == 'new_secret_access_key'
        storage.bucket.should             == 'new-bucket'
        storage.path.should               == 'new_path'
        storage.region.should             == 'new_region'

        storage.storage_id.should be_nil
        storage.keep.should       == 10
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#provider' do
    it 'should set the Fog provider' do
      storage.send(:provider).should == 'AWS'
    end
  end

  describe '#connection' do
    let(:connection) { mock }

    it 'should create a new connection' do
      Fog::Storage.expects(:new).once.with(
        :provider               => 'AWS',
        :aws_access_key_id      => 'my_access_key_id',
        :aws_secret_access_key  => 'my_secret_access_key',
        :region                 => 'us-east-1'
      ).returns(connection)
      storage.send(:connection).should == connection
    end

    it 'should return an existing connection' do
      Fog::Storage.expects(:new).once.returns(connection)
      storage.send(:connection).should == connection
      storage.send(:connection).should == connection
    end
  end # describe '#connection'

  describe '#remote_path_for' do
    let(:package) { mock }

    before do
      # for superclass method
      package.expects(:trigger).returns('trigger')
      package.expects(:time).returns('time')
    end

    it 'should remove any preceeding slash from the remote path' do
      storage.path = '/backups'
      storage.send(:remote_path_for, package).should == 'backups/trigger/time'
    end
  end

  describe '#transfer!' do
    let(:connection) { mock }
    let(:package) { mock }
    let(:file) { mock }
    let(:s) { sequence '' }

    before do
      storage.instance_variable_set(:@package, package)
      storage.stubs(:storage_name).returns('Storage::S3')
      storage.stubs(:local_path).returns('/local/path')
      storage.stubs(:connection).returns(connection)
    end

    it 'should transfer the package files' do
      storage.expects(:remote_path_for).in_sequence(s).with(package).
          returns('remote/path')
      connection.expects(:sync_clock).in_sequence(s)
      storage.expects(:files_to_transfer_for).in_sequence(s).with(package).
        multiple_yields(
        ['2011.12.31.11.00.02.backup.tar.enc-aa', 'backup.tar.enc-aa'],
        ['2011.12.31.11.00.02.backup.tar.enc-ab', 'backup.tar.enc-ab']
      )
      # first yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::S3 started transferring " +
        "'2011.12.31.11.00.02.backup.tar.enc-aa' to bucket 'my-bucket'."
      )
      File.expects(:open).in_sequence(s).with(
        File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-aa'), 'r'
      ).yields(file)
      connection.expects(:put_object).in_sequence(s).with(
        'my-bucket', File.join('remote/path', 'backup.tar.enc-aa'), file
      )
      # second yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::S3 started transferring " +
        "'2011.12.31.11.00.02.backup.tar.enc-ab' to bucket 'my-bucket'."
      )
      File.expects(:open).in_sequence(s).with(
        File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-ab'), 'r'
      ).yields(file)
      connection.expects(:put_object).in_sequence(s).with(
        'my-bucket', File.join('remote/path', 'backup.tar.enc-ab'), file
      )

      storage.send(:transfer!)
    end
  end # describe '#transfer!'

  describe '#remove!' do
    let(:package) { mock }
    let(:connection) { mock }
    let(:s) { sequence '' }

    before do
      storage.stubs(:storage_name).returns('Storage::S3')
      storage.stubs(:connection).returns(connection)
    end

    it 'should remove the package files' do
      storage.expects(:remote_path_for).in_sequence(s).with(package).
          returns('remote/path')
      connection.expects(:sync_clock).in_sequence(s)
      storage.expects(:transferred_files_for).in_sequence(s).with(package).
        multiple_yields(
        ['2011.12.31.11.00.02.backup.tar.enc-aa', 'backup.tar.enc-aa'],
        ['2011.12.31.11.00.02.backup.tar.enc-ab', 'backup.tar.enc-ab']
      )
      # first yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::S3 started removing " +
        "'2011.12.31.11.00.02.backup.tar.enc-aa' from bucket 'my-bucket'."
      )
      connection.expects(:delete_object).in_sequence(s).with(
        'my-bucket', File.join('remote/path', 'backup.tar.enc-aa')
      )
      # second yield
      Backup::Logger.expects(:message).in_sequence(s).with(
        "Storage::S3 started removing " +
        "'2011.12.31.11.00.02.backup.tar.enc-ab' from bucket 'my-bucket'."
      )
      connection.expects(:delete_object).in_sequence(s).with(
        'my-bucket', File.join('remote/path', 'backup.tar.enc-ab')
      )

      storage.send(:remove!, package)
    end
  end # describe '#remove!'

end
