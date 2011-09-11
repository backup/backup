# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Storage::Object do
  let(:object) { Backup::Storage::Object.new(:s3) }

  it do
    object.storage_file.should == File.join(Backup::DATA_PATH, Backup::TRIGGER, 's3.yml')
  end

  describe '#load' do
    it 'should return an array with objects' do
      File.expects(:exist?).returns(true)
      YAML.expects(:load_file).with(
        File.join(Backup::DATA_PATH, Backup::TRIGGER, 's3.yml')
      ).returns(YAML.load([Backup::Storage::S3.new, Backup::Storage::S3.new].to_yaml))

      objects = object.load
      objects.should be_an(Array)
      objects.first.should be_an_instance_of(Backup::Storage::S3)
    end

    describe 'loading them sorted by time descending (newest backup is first in the array)' do
      it do
        obj_1 = Backup::Storage::S3.new; obj_1.time = '2007.00.00.00.00.00'
        obj_2 = Backup::Storage::S3.new; obj_2.time = '2009.00.00.00.00.00'
        obj_3 = Backup::Storage::S3.new; obj_3.time = '2011.00.00.00.00.00'

        File.expects(:exist?).returns(true)
        YAML.expects(:load_file).with(
          File.join(Backup::DATA_PATH, Backup::TRIGGER, 's3.yml')
        ).returns(YAML.load([obj_1, obj_2, obj_3].to_yaml))

        objects = object.load
        objects[0].time.should == '2011.00.00.00.00.00'
        objects[1].time.should == '2009.00.00.00.00.00'
        objects[2].time.should == '2007.00.00.00.00.00'
      end

      it do
        obj_3 = Backup::Storage::S3.new; obj_3.time = '2007.00.00.00.00.00'
        obj_2 = Backup::Storage::S3.new; obj_2.time = '2009.00.00.00.00.00'
        obj_1 = Backup::Storage::S3.new; obj_1.time = '2011.00.00.00.00.00'

        File.expects(:exist?).returns(true)
        YAML.expects(:load_file).with(
          File.join(Backup::DATA_PATH, Backup::TRIGGER, 's3.yml')
        ).returns(YAML.load([obj_1, obj_2, obj_3].to_yaml))

        objects = object.load
        objects[0].time.should == '2011.00.00.00.00.00'
        objects[1].time.should == '2009.00.00.00.00.00'
        objects[2].time.should == '2007.00.00.00.00.00'
      end

      it do
        obj_3 = Backup::Storage::S3.new; obj_3.time = '2007.00.00.00.00.00'
        obj_1 = Backup::Storage::S3.new; obj_1.time = '2009.00.00.00.00.00'
        obj_2 = Backup::Storage::S3.new; obj_2.time = '2011.00.00.00.00.00'

        File.expects(:exist?).at_least_once.returns(true)
        YAML.expects(:load_file).with(
          File.join(Backup::DATA_PATH, Backup::TRIGGER, 's3.yml')
        ).returns(YAML.load([obj_1, obj_2, obj_3].to_yaml))

        objects = object.load
        objects[0].time.should == '2011.00.00.00.00.00'
        objects[1].time.should == '2009.00.00.00.00.00'
        objects[2].time.should == '2007.00.00.00.00.00'
      end
    end
  end
end
