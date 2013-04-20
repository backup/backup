# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::Base do
  let(:model)   { Backup::Model.new(:test_trigger, 'test label') }
  let(:package) { mock }
  let(:storage) { Backup::Storage::Base.new(model) }

  it 'should include Configuration::Helpers' do
    Backup::Storage::Base.
      include?(Backup::Configuration::Helpers).should be_true
  end

  describe '#initialize' do
    after { Backup::Storage::Base.clear_defaults! }

    it 'should load pre-configured defaults' do
      Backup::Storage::Base.any_instance.expects(:load_defaults!)
      storage
    end

    it 'should set a reference to the model' do
      storage.instance_variable_get(:@model).should == model
    end

    it 'should set a reference to the storage_id' do
      storage = Backup::Storage::Base.new(model, 'test_id')
      storage.storage_id.should == 'test_id'
    end

    it 'should not require the storage_id' do
      storage.instance_variable_defined?(:@storage_id).should be_true
      storage.storage_id.should be_nil
    end

    context 'when no pre-configured defaults have been set' do
      it 'should set default values' do
        storage.keep.should be_nil
        storage.storage_id.should be_nil
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Storage::Base.defaults do |s|
          s.keep = 5
        end
      end

      it 'should use pre-configured defaults' do
        storage.keep.should be(5)
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#perform!' do
    before do
      model.instance_variable_set(:@package, package)
    end

    it 'should call #transfer!, then #cycle!' do
      s = sequence ''
      storage.expects(:transfer!).in_sequence(s)
      storage.expects(:cycle!).in_sequence(s)
      storage.perform!
      storage.instance_variable_get(:@package).should be(package)
    end
  end

  describe '#storage_name' do
    context 'when given a storage_id' do
      it 'should return a log-friendly name with the storage_id' do
        storage = Backup::Storage::Base.new(model, 'storage id')
        storage.send(:storage_name).should == 'Storage::Base (storage id)'
      end
    end

    context 'when not given a storage_id' do
      it 'should return a log-friendly name without a storage_id' do
        storage.send(:storage_name).should == 'Storage::Base'
      end
    end
  end

  describe '#local_path' do
    it 'should return the configured tmp_path' do
      storage.send(:local_path).should == Backup::Config.tmp_path
    end
  end

  describe '#remote_path_for' do
    before do
      package.expects(:trigger).returns('test_trigger')
      package.expects(:time).returns('backup_time')
      storage.expects(:path).returns('base/remote/path')
    end

    it 'should return the remote_path for the given package' do
      storage.send(:remote_path_for, package).should ==
          File.join('base/remote/path', 'test_trigger', 'backup_time')
    end
  end

  describe '#files_to_transfer_for' do
    let(:given_block) { mock }
    before do
      package.stubs(:filenames).returns(
        ['backup.tar.enc-aa', 'backup.tar.enc-ab']
      )
    end

    it 'should yield the full filename and the filename without the timestamp' do
      given_block.expects(:got).with(
        'backup.tar.enc-aa', 'backup.tar.enc-aa'
      )
      given_block.expects(:got).with(
        'backup.tar.enc-ab', 'backup.tar.enc-ab'
      )
      storage.send(:files_to_transfer_for, package) do |local_file, remote_file|
        given_block.got(local_file, remote_file)
      end
    end

    it 'should have an alias method called #transferred_files_for' do
      storage.method(:transferred_files_for).should ==
          storage.method(:files_to_transfer_for)
    end
  end

  describe '#cycle!' do
    before do
      storage.stubs(:storage_name).returns('Storage Name')
      storage.instance_variable_set(:@package, package)
    end

    context 'when keep is set and > 0' do
      before { storage.keep = 1 }
      it 'should cycle' do
        s = sequence ''
        Backup::Logger.expects(:info).in_sequence(s).
            with('Storage Name: Cycling Started...')
        Backup::Storage::Cycler.expects(:cycle!).in_sequence(s).
            with(storage, package)
        Backup::Logger.expects(:info).in_sequence(s).
            with('Storage Name: Cycling Complete!')

        storage.send(:cycle!)
      end
    end

    context 'when keep is not set or == 0' do
      it 'should return nil when not set' do
        storage.keep = nil
        storage.send(:cycle!).should be_nil
      end

      it 'should return nil when == 0' do
        storage.keep = 0
        storage.send(:cycle!).should be_nil
      end
    end
  end

end
