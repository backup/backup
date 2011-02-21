# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Compressor::Gzip do
  let(:compressor) { Backup::Compressor::Gzip.new }

  before do
    Backup::Model.extension = 'tar'
  end

  it 'should have no additional options' do
    compressor.additional_options.should == []
  end

  it 'should have 2 options' do
    compressor = Backup::Compressor::Gzip.new do |c|
      c.additional_options = ['--fast', '--best']
    end

    compressor.additional_options.should == ['--fast', '--best']
  end

  describe '#perform!' do
    it 'should perform the compression' do
      compressor.expects(:utility).with(:gzip).returns(:gzip)
      compressor.expects(:run).with("gzip  '#{ File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar") }'")
      compressor.perform!
    end

    it 'should perform the compression with additional options' do
      compressor = Backup::Compressor::Gzip.new do |c|
        c.additional_options = ['--fast', '--best']
      end

      compressor.stubs(:utility).returns(:gzip)
      compressor.expects(:run).with("gzip --fast --best '#{ File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar") }'")
      compressor.perform!
    end

    it 'should set the class variable @extension (Backup::Model.extension) to .gz' do
      compressor.stubs(:utility).returns(:gzip)
      compressor.expects(:run)

      Backup::Model.extension.should == 'tar'
      compressor.perform!
      Backup::Model.extension.should == 'tar.gz'
    end
  end
end
