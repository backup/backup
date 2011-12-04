# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Compressor::Lzma do
  before do
    Backup::Configuration::Compressor::Lzma.defaults do |compressor|
      compressor.best = true
      compressor.fast = true
    end
  end

  it 'should set the default compressor configuration' do
    compressor = Backup::Configuration::Compressor::Lzma
    compressor.best.should == true
    compressor.fast.should == true
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Compressor::Lzma.clear_defaults!

      compressor = Backup::Configuration::Compressor::Lzma
      compressor.best.should == nil
      compressor.fast.should == nil
    end
  end
end
