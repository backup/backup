# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Compressor::Gzip do
  let(:compressor) { Backup::Compressor::Gzip.new }

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
      compressor.expects(:utility).with(:gzip).returns(:gzip)
      compressor.expects(:run).with("gzip  '#{ File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar") }'")
      compressor.perform!
    end

    it 'should perform the compression with the --best and --fast options' do
      compressor = Backup::Compressor::Gzip.new do |c|
        c.best = true
        c.fast = true
      end

      compressor.stubs(:utility).returns(:gzip)
      compressor.expects(:run).with("gzip --best --fast '#{ File.join(Backup::TMP_PATH, "#{ Backup::TIME }.#{ Backup::TRIGGER }.tar") }'")
      compressor.perform!
    end

    it 'should set the class variable @extension (Backup::Model.extension) to .gz' do
      compressor.stubs(:utility).returns(:gzip)
      compressor.expects(:run)

      Backup::Model.extension.should == 'tar'
      compressor.perform!
      Backup::Model.extension.should == 'tar.gz'
    end

    it 'should log' do
      Backup::Logger.expects(:message).with("Backup::Compressor::Gzip started compressing the archive.")
      compressor.perform!
    end
  end
end
