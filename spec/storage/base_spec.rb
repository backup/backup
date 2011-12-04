# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::Base do

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

    it 'removes old stored objects' do
      num_to_load = 5
      num_to_keep = 3

      s = sequence ''
      storage_object = mock
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
      objects_to_remove.each do |object_to_remove|
        Backup::Logger.expects(:message).in_sequence(s).
            with {|msg| msg.include?(object_to_remove.filename) }
        object_to_remove.expects(:remove!).in_sequence(s)
      end

      objects = objects - objects_to_remove
      objects.each {|object| object.expects(:clean!).in_sequence(s) }
      storage_object.expects(:write).in_sequence(s).
          with(objects)

      base.keep = num_to_keep
      base.send(:cycle!)
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
end
