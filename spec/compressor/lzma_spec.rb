# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Compressor::Lzma do
  before do
    Backup::Compressor::Lzma.any_instance.stubs(:utility).returns('lzma')
  end

  it 'should be a subclass of Compressor::Base' do
    Backup::Compressor::Lzma.
      superclass.should == Backup::Compressor::Base
  end

  describe '#initialize' do
    let(:compressor) { Backup::Compressor::Lzma.new }

    after { Backup::Compressor::Lzma.clear_defaults! }

    it 'should load pre-configured defaults' do
      Backup::Compressor::Lzma.any_instance.expects(:load_defaults!)
      compressor
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use default values' do
        compressor.best.should be_false
        compressor.fast.should be_false
      end

      it 'should use the values given' do
        compressor = Backup::Compressor::Lzma.new do |c|
          c.best = true
          c.fast = true
        end

        compressor.best.should be_true
        compressor.fast.should be_true
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Compressor::Lzma.defaults do |c|
          c.best = true
          c.fast = true
        end
      end

      it 'should use pre-configured defaults' do
        compressor.best.should be_true
        compressor.fast.should be_true
      end

      it 'should override pre-configured defaults' do
        compressor = Backup::Compressor::Lzma.new do |c|
          c.best = false
          c.fast = false
        end

        compressor.best.should be_false
        compressor.fast.should be_false
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#compress_with' do
    before do
      Backup::Compressor::Lzma.any_instance.expects(:log!)

      Backup::Logger.expects(:warn).with do |msg|
        msg.should match(
          /\[DEPRECATION WARNING\]\n  Compressor::Lzma is being deprecated/
        )
      end
    end

    it 'should yield with the --best option' do
      compressor = Backup::Compressor::Lzma.new do |c|
        c.best = true
      end

      compressor.compress_with do |cmd, ext|
        cmd.should == 'lzma --best'
        ext.should == '.lzma'
      end
    end

    it 'should yield with the --fast option' do
      compressor = Backup::Compressor::Lzma.new do |c|
        c.fast = true
      end

      compressor.compress_with do |cmd, ext|
        cmd.should == 'lzma --fast'
        ext.should == '.lzma'
      end
    end

    it 'should prefer the --best option over --fast' do
      compressor = Backup::Compressor::Lzma.new do |c|
        c.best = true
        c.fast = true
      end

      compressor.compress_with do |cmd, ext|
        cmd.should == 'lzma --best'
        ext.should == '.lzma'
      end
    end

    it 'should yield with no options' do
      compressor = Backup::Compressor::Lzma.new

      compressor.compress_with do |cmd, ext|
        cmd.should == 'lzma'
        ext.should == '.lzma'
      end
    end

  end # describe '#compress_with'

end
