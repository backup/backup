# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Compressor::Lzma do
  let(:compressor) { Backup::Compressor::Lzma.new }

  describe 'setting configuration defaults' do
    after { Backup::Configuration::Compressor::Lzma.clear_defaults! }

    it 'uses and overrides configuration defaults' do
      Backup::Configuration::Compressor::Lzma.best.should be_false
      Backup::Configuration::Compressor::Lzma.fast.should be_false

      compressor = Backup::Compressor::Lzma.new
      compressor.best.should be_false
      compressor.fast.should be_false

      Backup::Configuration::Compressor::Lzma.defaults do |c|
        c.best = true
        c.fast = true
      end
      Backup::Configuration::Compressor::Lzma.best.should be_true
      Backup::Configuration::Compressor::Lzma.fast.should be_true

      compressor = Backup::Compressor::Lzma.new
      compressor.best.should be_true
      compressor.fast.should be_true

      compressor = Backup::Compressor::Lzma.new do |c|
        c.best = false
      end
      compressor.best.should be_false
      compressor.fast.should be_true

      compressor = Backup::Compressor::Lzma.new do |c|
        c.fast = false
      end
      compressor.best.should be_true
      compressor.fast.should be_false
    end
  end # describe 'setting configuration defaults'

  describe '#compress_with' do
    before do
      compressor.expects(:log!)
      compressor.expects(:utility).with(:lzma).returns('lzma')
    end

    it 'should yield with the --best option' do
      compressor.best = true
      compressor.compress_with do |cmd, ext|
        cmd.should == 'lzma --best'
        ext.should == '.lzma'
      end
    end

    it 'should yield with the --fast option' do
      compressor.fast = true
      compressor.compress_with do |cmd, ext|
        cmd.should == 'lzma --fast'
        ext.should == '.lzma'
      end
    end

    it 'should yield with the --best and --fast options' do
      compressor.best = true
      compressor.fast = true
      compressor.compress_with do |cmd, ext|
        cmd.should == 'lzma --best --fast'
        ext.should == '.lzma'
      end
    end

    it 'should yield with no options' do
      compressor.compress_with do |cmd, ext|
        cmd.should == 'lzma'
        ext.should == '.lzma'
      end
    end
  end # describe '#compress_with'

end
