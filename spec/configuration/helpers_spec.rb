# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe 'Backup::Configuration::Helpers' do

  before do
    module Backup
      class Foo
        attr_accessor :accessor
        attr_reader :reader
        include Backup::Configuration::Helpers
      end
    end
  end

  after do
    Backup.send(:remove_const, 'Foo')
  end

  describe '.defaults' do
    let(:configuration) { mock }

    before do
      Backup::Configuration::Store.expects(:new).once.returns(configuration)
    end

    it 'should return the Configuration::Store for the class' do
      Backup::Foo.defaults.should be(configuration)
    end

    it 'should yield the Configuration::Store for the class' do
      Backup::Foo.defaults do |config|
        config.should be(configuration)
      end
    end

    it 'should cache the Configuration::Store for the class' do
      Backup::Foo.instance_variable_get(:@configuration).should be_nil
      Backup::Foo.defaults.should be(configuration)
      Backup::Foo.instance_variable_get(:@configuration).should be(configuration)
      Backup::Foo.defaults.should be(configuration)
    end
  end

  describe '#load_defaults!' do
    let(:klass) { Backup::Foo.new }

    it 'should load default values set for the class' do
      Backup::Foo.defaults do |config|
        config.accessor = 'foo'
      end

      klass.send(:load_defaults!)
      klass.accessor.should == 'foo'
    end

    it 'should raise an error if defaults are set for attribute readers' do
      Backup::Foo.defaults do |config|
        config.reader = 'foo'
      end

      expect do
        klass.send(:load_defaults!)
      end.to raise_error(NoMethodError, /Backup::Foo/)
    end

    it 'should raise an error if defaults were set for invalid accessors' do
      Backup::Foo.defaults do |config|
        config.foobar = 'foo'
      end

      expect do
        klass.send(:load_defaults!)
      end.to raise_error(NoMethodError, /Backup::Foo/)
    end
  end

  describe '#clear_defaults!' do
    it 'should clear all defaults set' do
      Backup::Foo.defaults do |config|
        config.accessor = 'foo'
      end
      Backup::Foo.defaults.accessor.should == 'foo'

      Backup::Foo.clear_defaults!
      Backup::Foo.defaults.accessor.should be_nil
    end
  end
end
