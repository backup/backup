# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Compressor::Bzip2 do
  let(:compressor) { Backup::Compressor::Bzip2.new }

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
  end

  describe '#perform!' do
    before do
      [:run, :utility].each { |method| compressor.stubs(method) }
    end

    it 'should perform the compression' do
      compressor.expects(:utility).with(:bzip2).returns(:bzip2)
      compressor.expects(:run).with("bzip2  '#{ File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar") }'")
      compressor.perform!
    end

    it 'should perform the compression with the --best and --fast options' do
      compressor = Backup::Compressor::Bzip2.new do |c|
        c.best = true
        c.fast = true
      end

      compressor.stubs(:utility).returns(:bzip2)
      compressor.expects(:run).with("bzip2 --best --fast '#{ File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar") }'")
      compressor.perform!
    end

    it 'should set the class variable @extension (Backup::Model.extension) to .bz2' do
      compressor.stubs(:utility).returns(:bzip2)
      compressor.expects(:run)

      Backup::Model.extension.should == 'tar'
      compressor.perform!
      Backup::Model.extension.should == 'tar.bz2'
    end

    it 'should log' do
      Backup::Logger.expects(:message).with("Backup::Compressor::Bzip2 started compressing the archive.")
      compressor.perform!
    end
  end
end
