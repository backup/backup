# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::OSS do
  let(:model)   { Backup::Model.new(:test_trigger, 'test label') }
  let(:storage) do
    Backup::Storage::OSS.new(model) do |db|
      db.access_id      = 'my_access_id'
      db.access_key   = 'my_access_key'
      db.bucket       = 'foo'
      db.keep         = 5
    end
  end

  it 'should be a subclass of Storage::Base' do
    Backup::Storage::OSS.
      superclass.should == Backup::Storage::Base
  end

  describe '#initialize' do
    after { Backup::Storage::OSS.clear_defaults! }

    it 'should load pre-configured defaults through Base' do
      Backup::Storage::OSS.any_instance.expects(:load_defaults!)
      storage
    end

    it 'should pass the model reference to Base' do
      storage.instance_variable_get(:@model).should == model
    end

    it 'should pass the storage_id to Base' do
      storage = Backup::Storage::OSS.new(model, 'my_storage_id')
      storage.storage_id.should == 'my_storage_id'
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        storage.access_id.should      == 'my_access_id'
        storage.access_key.should   == 'my_access_key'
        storage.bucket.should  == "foo"
        storage.path.should         == 'backups'

        storage.storage_id.should be_nil
        storage.keep.should       == 5
      end

      it 'should use default values if none are given' do
        storage = Backup::Storage::OSS.new(model)
        storage.access_id.should      be_nil
        storage.access_key.should   be_nil
        storage.bucket.should       be_nil
        storage.path.should         == 'backups'

        storage.storage_id.should be_nil
        storage.keep.should       be_nil
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Storage::OSS.defaults do |s|
          s.access_id      = 'some_api_key'
          s.access_key   = 'some_api_secret'
          s.bucket  = 'some_bucket'
          s.path         = 'some_path'
          s.keep         = 15
        end
      end

      it 'should use pre-configured defaults' do
        storage = Backup::Storage::OSS.new(model)

        storage.access_id.should      == 'some_api_key'
        storage.access_key.should   == 'some_api_secret'
        storage.bucket.should  == 'some_bucket'
        storage.path.should         == 'some_path'

        storage.storage_id.should be_nil
        storage.keep.should       == 15
      end

      it 'should override pre-configured defaults' do
        storage = Backup::Storage::OSS.new(model) do |s|
          s.access_id      = 'new_api_key'
          s.access_key   = 'new_api_secret'
          s.bucket  = 'new_bucket'
          s.path         = 'new_path'
          s.keep         = 10
        end

        storage.access_id.should      == 'new_api_key'
        storage.access_key.should   == 'new_api_secret'
        storage.bucket.should  == 'new_bucket'
        storage.path.should         == 'new_path'

        storage.storage_id.should be_nil
        storage.keep.should       == 10
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#transfer!' do
    let(:connection) { mock }
    let(:package) { mock }
    let(:file) { mock }
    let(:s) { sequence '' }

    before do
      storage.instance_variable_set(:@package, package)
      storage.stubs(:storage_name).returns('Storage::OSS')
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
      Backup::Logger.expects(:info).in_sequence(s).with(
        "Storage::OSS started transferring " +
        "'2011.12.31.11.00.02.backup.tar.enc-aa'."
      )
      File.expects(:open).in_sequence(s).with(
        File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-aa'), 'r'
      ).yields(file)
      connection.expects(:put).in_sequence(s).with(
        File.join('remote/path', 'backup.tar.enc-aa'), file
      )
      # second yield
      Backup::Logger.expects(:info).in_sequence(s).with(
        "Storage::OSS started transferring " +
        "'2011.12.31.11.00.02.backup.tar.enc-ab'."
      )
      File.expects(:open).in_sequence(s).with(
        File.join('/local/path', '2011.12.31.11.00.02.backup.tar.enc-ab'), 'r'
      ).yields(file)
      connection.expects(:put).in_sequence(s).with(
        File.join('remote/path', 'backup.tar.enc-ab'), file
      )

      storage.send(:transfer!)
    end
  end # describe '#transfer!'

  describe '#remove!' do
    let(:package) { mock }
    let(:connection) { mock }
    let(:s) { sequence '' }

    before do
      storage.stubs(:storage_name).returns('Storage::OSS')
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
      # after both yields
      Backup::Logger.expects(:info).in_sequence(s).with(
        "Storage::OSS started removing " +
        "'2011.12.31.11.00.02.backup.tar.enc-aa' from Aliyun OSS.\n" +
        "Storage::OSS started removing " +
        "'2011.12.31.11.00.02.backup.tar.enc-ab' from Aliyun OSS."
      )
      connection.expects(:delete).in_sequence(s).with('remote/path')

      storage.send(:remove!, package)
    end
  end # describe '#remove!'


end
