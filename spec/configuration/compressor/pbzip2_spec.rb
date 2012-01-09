# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Compressor::Pbzip2 do
  before do
    Backup::Configuration::Compressor::Pbzip2.defaults do |compressor|
      compressor.best = true
      compressor.fast = true
      compressor.processors = 2
    end
  end

  it 'should set the default compressor configuration' do
    compressor = Backup::Configuration::Compressor::Pbzip2
    compressor.best.should == true
    compressor.fast.should == true
    compressor.processors.should == 2
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Compressor::Pbzip2.clear_defaults!

      compressor = Backup::Configuration::Compressor::Pbzip2
      compressor.best.should == nil
      compressor.fast.should == nil
      compressor.processors.should == nil
    end
  end
end
