# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Storage::Object do

  describe '#initialize' do

    it 'uses storage type only as YAML filename if no storage_id' do
      [nil, '', ' '].each do |storage_id|
        object = Backup::Storage::Object.new(:s3, storage_id)
        object.storage_file.should == File.join(Backup::DATA_PATH, Backup::TRIGGER, 's3.yml')
      end
    end

    it 'appends optional storage_id' do
      object = Backup::Storage::Object.new(:s3, 'foo')
      object.storage_file.should == File.join(Backup::DATA_PATH, Backup::TRIGGER, 's3-foo.yml')
    end

    it 'sanitizes user-defined storage_id for use as filename' do
      [ ['Backup Server #1', 'Backup_Server__1'],
        [' {Special} Storage ', '_Special__Storage'],
        ['Cloud (!@$%^&*) #9', 'Cloud____________9'] ].each do |input, sanitized|
        object = Backup::Storage::Object.new(:s3, input)
        object.storage_file.should == File.join(Backup::DATA_PATH, Backup::TRIGGER, "s3-#{sanitized}.yml")
      end
    end

  end

  describe '#load' do
    let(:storage_object) { Backup::Storage::Object.new(:s3, nil) }

    it 'should return an array with objects' do
      loaded_objects = YAML.load([Backup::Storage::S3.new, Backup::Storage::S3.new].to_yaml)
      sorted_objects = loaded_objects.sort {|a,b| b.time <=> a.time }

      File.expects(:exist?).returns(true)
      YAML.expects(:load_file).with(
        File.join(Backup::DATA_PATH, Backup::TRIGGER, 's3.yml')
      ).returns(loaded_objects)

      objects = storage_object.load
      objects.should be_an(Array)
      objects.first.should be_an_instance_of(Backup::Storage::S3)
    end

    it 'should load them sorted by time descending (newest backup is first in the array)' do
      obj_1 = Backup::Storage::S3.new; obj_1.time = '2007.00.00.00.00.00'
      obj_2 = Backup::Storage::S3.new; obj_2.time = '2009.00.00.00.00.00'
      obj_3 = Backup::Storage::S3.new; obj_3.time = '2011.00.00.00.00.00'

      File.stubs(:exist?).returns(true)
      File.stubs(:zero?).returns(false)

      [obj_1, obj_2, obj_3].permutation.each do |perm|
        loaded_objects = YAML.load(perm.to_yaml)
        sorted_objects = loaded_objects.sort {|a,b| b.time <=> a.time }

        YAML.expects(:load_file).with(
          File.join(Backup::DATA_PATH, Backup::TRIGGER, 's3.yml')
        ).returns(loaded_objects)

        objects = storage_object.load
        objects[0].time.should == '2011.00.00.00.00.00'
        objects[1].time.should == '2009.00.00.00.00.00'
        objects[2].time.should == '2007.00.00.00.00.00'
      end
    end

  end

end
