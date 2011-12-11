# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::Base do

  describe '#initialize' do

    after do
      Backup::Configuration::Storage::Base.clear_defaults!
    end

    it 'should create a new storage object with default values' do
      base = Backup::Storage::Base.new
      base.keep.should be_nil
      base.time.should == Backup::TIME
    end

    it 'should set configured defaults' do
      Backup::Configuration::Storage::Base.defaults do |base|
        base.keep = 5
      end

      base = Backup::Storage::Base.new
      base.keep.should == 5
      base.time.should == Backup::TIME
    end

    it 'should override the configuration defaults with the configure block' do
      Backup::Configuration::Storage::Base.defaults do |base|
        base.keep = 5
      end

      base = Backup::Storage::Base.new do |base|
        base.keep = 10
      end
      base.keep.should == 10
      base.time.should == Backup::TIME
    end

    it 'should store the configuration block' do
      config_block = lambda {|base| base.keep = 10 }
      base = Backup::Storage::Base.new(&config_block)

      base.keep.should == 10
      base.configure_block.should be config_block
    end

    it 'should set the storage_id using an optional block parameter' do
      base = Backup::Storage::Base.new('my storage_id') do |base|
        base.keep = 10
      end
      base.keep.should == 10
      base.time.should == Backup::TIME
      base.storage_id.should == 'my storage_id'
    end

  end # describe '#inititalize'

  describe '#clean!' do

    it 'clears all instance variables except those needed for cycling' do
      cycle_required_variables = %w[ @filename @time @chunk_suffixes ].sort

      base = Backup::Storage::Base.new do |config|
        config.storage_id = 'bar_id'
        config.keep = 3
      end
      base.time = Time.utc(2011, 12, 2)
      base.chunk_suffixes = ['aa', 'ab']
      base.instance_variable_set(:@filename, 'foo.tar')

      base.send(:clean!)
      base.instance_variables.map(&:to_s).sort.should == cycle_required_variables
      base.time.should == Time.utc(2011, 12, 2)
      base.chunk_suffixes.should == ['aa', 'ab']
      base.filename.should == 'foo.tar'
    end

  end

  describe '#update!' do

    it 'updates the storage object with the given configure_block' do
      base_a = Backup::Storage::Base.new do |config|
        config.storage_id = 'foo_id'
        config.keep = 5
      end
      base_b = Backup::Storage::Base.new do |config|
        config.storage_id = 'bar_id'
        config.keep = 3
      end
      base_b.send(:update!, base_a.configure_block)
      base_b.storage_id.should == 'foo_id'
      base_b.keep.should == 5
    end

    it 'updates YAML loaded objects, which were `cleaned` for cycling' do
      base = Backup::Storage::Base.new do |config|
        config.storage_id = 'foo_id'
        config.keep = 5
      end
      base.time.should == Backup::TIME

      loaded = Backup::Storage::Base.new do |config|
        config.storage_id = 'bar_id'
        config.keep = 3
      end
      loaded.time = Time.utc(2011, 12, 2)
      loaded.chunk_suffixes = ['aa', 'ab']
      loaded.instance_variable_set(:@filename, 'foo.tar')

      loaded.send(:clean!)
      loaded.storage_id.should == nil
      loaded.keep.should == nil

      loaded.send(:update!, base.configure_block)
      loaded.storage_id.should == 'foo_id'
      loaded.keep.should == 5
      loaded.time.should == Time.utc(2011, 12, 2)
      loaded.chunk_suffixes.should == ['aa', 'ab']
      loaded.filename.should == 'foo.tar'
    end

  end

  describe '#cycle!' do
    let(:base) { Backup::Storage::Base.new {} }

    it 'updates loaded objects and adds current object' do
      s = sequence ''
      storage_object = mock
      loaded_object = mock

      Backup::Storage::Object.expects(:new).in_sequence(s).
          with('Base', nil).returns(storage_object)
      storage_object.expects(:load).in_sequence(s).
          returns([loaded_object])
      loaded_object.expects(:update!).in_sequence(s).
          with(base.configure_block)
      objects = [base, loaded_object]
      objects.each {|object| object.expects(:clean!).in_sequence(s) }
      storage_object.expects(:write).in_sequence(s).
          with(objects)

      base.keep = 2
      base.send(:cycle!)
    end

    context 'when removing old stored objects' do

      it 'should warn and continue on errors' do
        num_to_load = 6
        num_to_keep = 3
        obj_to_fail = 2 # we're removing 3, so fail the 2nd one.

        s = sequence ''
        storage_object = mock
        raised_error = StandardError.new
        loaded_objects = []
        (1..num_to_load).each do |n|
          instance_eval <<-EOS
            loaded_object#{n} = mock
            loaded_object#{n}.stubs(:filename).returns("file#{n}")
            loaded_objects << loaded_object#{n}
          EOS
        end

        Backup::Storage::Object.expects(:new).in_sequence(s).
            with('Base', nil).returns(storage_object)
        storage_object.expects(:load).in_sequence(s).
            returns(loaded_objects)
        loaded_objects.each do |loaded_object|
          loaded_object.expects(:update!).in_sequence(s).
              with(base.configure_block)
        end
        objects = [base] + loaded_objects

        objects_to_remove = objects[num_to_keep..-1]
        objects_to_remove.each_with_index do |object_to_remove, i|
          Backup::Logger.expects(:message).in_sequence(s).
              with {|msg| msg.include?(object_to_remove.filename) }
          if i == obj_to_fail
            object_to_remove.expects(:remove!).in_sequence(s).
                raises(raised_error)
            Backup::Errors::Storage::CycleError.expects(:wrap).in_sequence(s).
                with(raised_error, "#{base.storage_name} failed to remove " +
                    "'#{object_to_remove.filename}'").
                returns(:wrapped_error)
            Backup::Logger.expects(:warn).in_sequence(s).
                with(:wrapped_error)
          else
            object_to_remove.expects(:remove!).in_sequence(s)
          end
        end

        objects = objects - objects_to_remove
        objects.each {|object| object.expects(:clean!).in_sequence(s) }
        storage_object.expects(:write).in_sequence(s).
            with(objects)

        base.keep = num_to_keep
        base.send(:cycle!)
      end

    end

  end

  describe '#chunks' do

    it 'returns sorted filenames for chunk_suffixes' do
      base = Backup::Storage::Base.new
      base.chunk_suffixes = ["aa", "ad", "ae", "ab", "ac"]
      base.stubs(:filename).returns("file.tar")
      base.chunks.should == [
        "#{base.filename}-aa",
        "#{base.filename}-ab",
        "#{base.filename}-ac",
        "#{base.filename}-ad",
        "#{base.filename}-ae",
      ]

      base.chunk_suffixes.should == ["aa", "ad", "ae", "ab", "ac"]
    end

  end

  describe '#storage_name' do
    let(:s3) { Backup::Storage::S3.new {} }

    describe 'returns storage class name with the Backup:: namespace removed' do

      context 'when storage_id is set' do
        before { s3.storage_id = 'my storage' }

        it 'appends the storage_id' do
          s3.storage_name.should == 'Storage::S3 (my storage)'
        end
      end

      context 'when storage_id is not set' do
        it 'does not append the storage_id' do
          s3.storage_name.should == 'Storage::S3'
        end
      end

    end

  end
end
