# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::Base do
  let(:model)   { Backup::Model.new(:test_trigger, 'test label') }
  let(:package) { mock }
  let(:base)    { Backup::Storage::Base.new(model) }

  describe '#initialize' do
    it 'should set instance variables' do
      base.instance_variable_get(:@model).should be(model)
      base.instance_variable_defined?(:@storage_id).should be_true
      base.instance_variable_get(:@storage_id).should be_nil
      base.keep.should be_nil
    end

    context 'when given a storage_id' do
      it 'should set @storage_id' do
        base = Backup::Storage::Base.new(model, 'my storage id')
        base.instance_variable_get(:@storage_id).should == 'my storage id'
      end
    end

    context 'when configuration defaults are set' do
      after { Backup::Configuration::Storage::Base.clear_defaults! }
      it 'should use the defaults' do
        Backup::Configuration::Storage::Base.defaults do |base|
          base.keep = 5
        end
        base = Backup::Storage::Base.new(model)
        base.keep.should be(5)
      end
    end
  end # describe '#initialize'

  describe '#perform!' do
    before do
      model.instance_variable_set(:@package, package)
    end

    it 'should call #transfer!, then #cycle!' do
      s = sequence ''
      base.expects(:transfer!).in_sequence(s)
      base.expects(:cycle!).in_sequence(s)
      base.perform!
      base.instance_variable_get(:@package).should be(package)
    end
  end

  describe '#storage_name' do
    context 'when given a storage_id' do
      before { base.storage_id = 'storage id' }
      it 'should return a log-friendly name with the storage_id' do
        base.send(:storage_name).should == 'Storage::Base (storage id)'
      end
    end

    context 'when not given a storage_id' do
      it 'should return a log-friendly name without a storage_id' do
        base.send(:storage_name).should == 'Storage::Base'
      end
    end
  end

  describe '#local_path' do
    it 'should return the configured tmp_path' do
      base.send(:local_path).should == Backup::Config.tmp_path
    end
  end

  describe '#remote_path_for' do
    before do
      package.expects(:trigger).returns('test_trigger')
      package.expects(:time).returns('backup_time')
      base.expects(:path).returns('base/remote/path')
    end

    it 'should return the remote_path for the given package' do
      base.send(:remote_path_for, package).should ==
          File.join('base/remote/path', 'test_trigger', 'backup_time')
    end
  end

  describe '#files_to_transfer_for' do
    let(:given_block) { mock }
    before do
      package.stubs(:filenames).returns(
        ['2011.12.31.11.00.02.backup.tar.enc-aa',
         '2011.12.31.11.00.02.backup.tar.enc-ab']
      )
    end

    it 'should yield the full filename and the filename without the timestamp' do
      given_block.expects(:got).with(
        '2011.12.31.11.00.02.backup.tar.enc-aa', 'backup.tar.enc-aa'
      )
      given_block.expects(:got).with(
        '2011.12.31.11.00.02.backup.tar.enc-ab', 'backup.tar.enc-ab'
      )
      base.send(:files_to_transfer_for, package) do |local_file, remote_file|
        given_block.got(local_file, remote_file)
      end
    end

    it 'should have an alias method called #transferred_files_for' do
      base.method(:transferred_files_for).should ==
          base.method(:files_to_transfer_for)
    end
  end

  describe '#cycle!' do
    before do
      base.stubs(:storage_name).returns('Storage Name')
      base.instance_variable_set(:@package, package)
    end

    context 'when keep is set and > 0' do
      before { base.keep = 1 }
      it 'should cycle' do
        s = sequence ''
        Backup::Logger.expects(:message).in_sequence(s).
            with('Storage Name: Cycling Started...')
        Backup::Storage::Cycler.expects(:cycle!).in_sequence(s).
            with(base, package)
        Backup::Logger.expects(:message).in_sequence(s).
            with('Storage Name: Cycling Complete!')

        base.send(:cycle!)
      end
    end

    context 'when keep is not set or == 0' do
      it 'should return nil when not set' do
        base.keep = nil
        base.send(:cycle!).should be_nil
      end

      it 'should return nil when == 0' do
        base.keep = 0
        base.send(:cycle!).should be_nil
      end
    end
  end

end
