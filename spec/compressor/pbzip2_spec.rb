# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Compressor::Pbzip2 do
  before do
    Backup::Compressor::Pbzip2.any_instance.stubs(:utility).returns('pbzip2')
  end

  it 'should be a subclass of Compressor::Base' do
    Backup::Compressor::Pbzip2.
      superclass.should == Backup::Compressor::Base
  end

  describe '#initialize' do
    let(:compressor) { Backup::Compressor::Pbzip2.new }

    after { Backup::Compressor::Pbzip2.clear_defaults! }

    it 'should load pre-configured defaults' do
      Backup::Compressor::Pbzip2.any_instance.expects(:load_defaults!)
      compressor
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use default values' do
        compressor.best.should be_false
        compressor.fast.should be_false
        compressor.processors.should be_false
      end

      it 'should use the values given' do
        compressor = Backup::Compressor::Pbzip2.new do |c|
          c.best = true
          c.fast = true
          c.processors = 2
        end

        compressor.best.should be_true
        compressor.fast.should be_true
        compressor.processors.should == 2
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Compressor::Pbzip2.defaults do |c|
          c.best = true
          c.fast = true
          c.processors = 2
        end
      end

      it 'should use pre-configured defaults' do
        compressor.best.should be_true
        compressor.fast.should be_true
        compressor.processors.should == 2
      end

      it 'should override pre-configured defaults' do
        compressor = Backup::Compressor::Pbzip2.new do |c|
          c.best = false
          c.fast = false
          c.processors = 4
        end

        compressor.best.should be_false
        compressor.fast.should be_false
        compressor.processors.should == 4
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#compress_with' do
    before do
      Backup::Compressor::Pbzip2.any_instance.expects(:log!)

      Backup::Logger.expects(:warn).with do |msg|
        msg.should match(
          /\[DEPRECATION WARNING\]\n  Compressor::Pbzip2 is being deprecated/
        )
      end
    end

    it 'should yield with the --best option' do
      compressor = Backup::Compressor::Pbzip2.new do |c|
        c.best = true
      end

      compressor.compress_with do |cmd, ext|
        cmd.should == 'pbzip2 --best'
        ext.should == '.bz2'
      end
    end

    it 'should yield with the --fast option' do
      compressor = Backup::Compressor::Pbzip2.new do |c|
        c.fast = true
      end

      compressor.compress_with do |cmd, ext|
        cmd.should == 'pbzip2 --fast'
        ext.should == '.bz2'
      end
    end

    it 'should yield with the -p option' do
      compressor = Backup::Compressor::Pbzip2.new do |c|
        c.processors = 2
      end

      compressor.compress_with do |cmd, ext|
        cmd.should == 'pbzip2 -p2'
        ext.should == '.bz2'
      end
    end

    it 'should prefer the --best option over --fast' do
      compressor = Backup::Compressor::Pbzip2.new do |c|
        c.best = true
        c.fast = true
      end

      compressor.compress_with do |cmd, ext|
        cmd.should == 'pbzip2 --best'
        ext.should == '.bz2'
      end
    end

    it 'should yield with the --best and -p options' do
      compressor = Backup::Compressor::Pbzip2.new do |c|
        c.best = true
        c.processors = 2
      end

      compressor.compress_with do |cmd, ext|
        cmd.should == 'pbzip2 --best -p2'
        ext.should == '.bz2'
      end
    end

    it 'should yield with the --fast and -p options' do
      compressor = Backup::Compressor::Pbzip2.new do |c|
        c.fast = true
        c.processors = 2
      end

      compressor.compress_with do |cmd, ext|
        cmd.should == 'pbzip2 --fast -p2'
        ext.should == '.bz2'
      end
    end

    it 'should yield with no options' do
      compressor = Backup::Compressor::Pbzip2.new

      compressor.compress_with do |cmd, ext|
        cmd.should == 'pbzip2'
        ext.should == '.bz2'
      end
    end

  end # describe '#compress_with'

end
