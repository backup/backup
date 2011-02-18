# encoding: utf-8

require File.dirname(__FILE__) + '/spec_helper'

module Backup::Adapters
  class TestAdapter
    def initialize(&block); end
  end
end

describe Backup::Model do

  it 'should create a new model with a trigger and label' do
    model = Backup::Model.new('mysql-s3', 'MySQL S3 Backup for MyApp') {}
    model.trigger.should == 'mysql-s3'
    model.label.should == 'MySQL S3 Backup for MyApp'
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

end
