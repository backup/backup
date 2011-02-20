# encoding: utf-8

require File.dirname(__FILE__) + '/spec_helper'

##
# Mocks - Adapter
module Backup::Adapter
  class TestAdapter
    def initialize(&block); end
  end
end

##
# Mocks - Storage
module Backup::Storage
  class TestStorage
    def initialize(&block); end
  end
end

describe Backup::Model do

  it 'should create a new model with a trigger and label' do
    model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') {}
    model.trigger.should == 'mysql-s3'
    model.label.should == 'MySQL S3 Backup for MyApp'
  end

  it 'should have the time logged in the object' do
    model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') {}
    model.time.should == TIME
  end

  describe 'adapters' do
    it 'should add the mysql adapter to the array of adapters to invoke' do
      model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') do
        use_adapter 'TestAdapter' do |a|
        end
      end

      model.adapters.count.should == 1
    end

    it 'should add 2 mysql adapters to the array of adapters to invoke' do
      model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') do
        use_adapter 'TestAdapter' do |a|
        end
        use_adapter 'TestAdapter' do |a|
        end
      end

      model.adapters.count.should == 2
    end
  end

  describe 'storages' do
    it 'should add a storage to the array of storages to use' do
      model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') do
        store_to 'TestStorage' do |a|
        end
      end

      model.storages.count.should == 1
    end

    it 'should add a storage to the array of storages to use' do
      model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') do
        store_to 'TestStorage' do |a|
        end
        store_to 'TestStorage' do |a|
        end
      end

      model.storages.count.should == 2
    end
  end

end
