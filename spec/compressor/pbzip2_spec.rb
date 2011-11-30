# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Compressor::Pbzip2 do
  let(:compressor) { Backup::Compressor::Pbzip2.new }

  before do
    Backup::Model.extension = 'tar'
  end

  describe 'the options' do
    it do
      compressor.send(:best).should == []
    end

    it do
      compressor.send(:fast).should == []
    end
    
    it do
      compressor.send(:processors).should == []
    end
  end

  describe '#perform!' do
    before do
      [:run, :utility].each { |method| compressor.stubs(method) }
    end

    it 'should perform the compression' do
      compressor.expects(:utility).with(:pbzip2).returns(:pbzip2)
      compressor.expects(:run).with("pbzip2  '#{ File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar") }'")
      compressor.perform!
    end

    it 'should perform the compression with the --best, --fast and -p1 options' do
      compressor = Backup::Compressor::Pbzip2.new do |c|
        c.best = true
        c.fast = true
        c.processors = 1
      end

      compressor.stubs(:utility).returns(:pbzip2)
      compressor.expects(:run).with("pbzip2 --best --fast -p1 '#{ File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar") }'")
      compressor.perform!
    end

    it 'should set the class variable @extension (Backup::Model.extension) to .bz2' do
      compressor.stubs(:utility).returns(:pbzip2)
      compressor.expects(:run)

      Backup::Model.extension.should == 'tar'
      compressor.perform!
      Backup::Model.extension.should == 'tar.bz2'
    end

    it 'should log' do
      Backup::Logger.expects(:message).with("Backup::Compressor::Pbzip2 started compressing the archive.")
      compressor.perform!
    end
  end
end
