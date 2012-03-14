# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Compressor::Bzip2 do
  let(:compressor) { Backup::Compressor::Bzip2.new }

  it 'should be a subclass of Compressor::Base' do
    Backup::Compressor::Bzip2.
      superclass.should == Backup::Compressor::Base
  end

  describe '#initialize' do
    after { Backup::Compressor::Bzip2.clear_defaults! }

    it 'should load pre-configured defaults' do
      Backup::Compressor::Bzip2.any_instance.expects(:load_defaults!)
      compressor
    end

    it 'should use pre-configured defaults' do
      Backup::Compressor::Bzip2.defaults do |c|
        c.best = true
        c.fast = true
      end
      compressor.best.should be_true
      compressor.fast.should be_true
    end

    it 'should set defaults when no pre-configured defaults are set' do
      compressor.best.should be_false
      compressor.fast.should be_false
    end

    it 'should override pre-configured defaults' do
      Backup::Compressor::Bzip2.defaults do |c|
        c.best = true
        c.fast = true
      end
      compressor = Backup::Compressor::Bzip2.new do |c|
        c.best = false
        c.fast = false
      end
      compressor.best.should be_false
      compressor.fast.should be_false
    end
  end # describe '#initialize'

  describe '#compress_with' do
    before do
      compressor.expects(:log!)
      compressor.expects(:utility).with(:bzip2).returns('bzip2')
    end

    it 'should yield with the --best option' do
      compressor.best = true
      compressor.compress_with do |cmd, ext|
        cmd.should == 'bzip2 --best'
        ext.should == '.bz2'
      end
    end

    it 'should yield with the --fast option' do
      compressor.fast = true
      compressor.compress_with do |cmd, ext|
        cmd.should == 'bzip2 --fast'
        ext.should == '.bz2'
      end
    end

    it 'should yield with the --best and --fast options' do
      compressor.best = true
      compressor.fast = true
      compressor.compress_with do |cmd, ext|
        cmd.should == 'bzip2 --best --fast'
        ext.should == '.bz2'
      end
    end

    it 'should yield with no options' do
      compressor.compress_with do |cmd, ext|
        cmd.should == 'bzip2'
        ext.should == '.bz2'
      end
    end
  end # describe '#compress_with'

end
