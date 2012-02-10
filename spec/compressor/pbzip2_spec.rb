# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Compressor::Pbzip2 do
  let(:compressor) { Backup::Compressor::Pbzip2.new }

  describe 'setting configuration defaults' do
    after { Backup::Configuration::Compressor::Pbzip2.clear_defaults! }

    it 'uses and overrides configuration defaults' do
      Backup::Configuration::Compressor::Pbzip2.best.should be_false
      Backup::Configuration::Compressor::Pbzip2.fast.should be_false
      Backup::Configuration::Compressor::Pbzip2.processors.should be_false

      compressor = Backup::Compressor::Pbzip2.new
      compressor.best.should be_false
      compressor.fast.should be_false
      compressor.processors.should be_false

      Backup::Configuration::Compressor::Pbzip2.defaults do |c|
        c.best = true
        c.fast = true
        c.processors = 2
      end
      Backup::Configuration::Compressor::Pbzip2.best.should be_true
      Backup::Configuration::Compressor::Pbzip2.fast.should be_true
      Backup::Configuration::Compressor::Pbzip2.processors.should == 2

      compressor = Backup::Compressor::Pbzip2.new
      compressor.best.should be_true
      compressor.fast.should be_true
      compressor.processors.should == 2

      compressor = Backup::Compressor::Pbzip2.new do |c|
        c.best = false
      end
      compressor.best.should be_false
      compressor.fast.should be_true
      compressor.processors.should == 2

      compressor = Backup::Compressor::Pbzip2.new do |c|
        c.fast = false
      end
      compressor.best.should be_true
      compressor.fast.should be_false
      compressor.processors.should == 2

      compressor = Backup::Compressor::Pbzip2.new do |c|
        c.processors = false
      end
      compressor.best.should be_true
      compressor.fast.should be_true
      compressor.processors.should be_false
    end
  end # describe 'setting configuration defaults'

  describe '#compress_with' do
    before do
      compressor.expects(:log!)
      compressor.expects(:utility).with(:pbzip2).returns('pbzip2')
    end

    it 'should yield with the --best option' do
      compressor.best = true
      compressor.compress_with do |cmd, ext|
        cmd.should == 'pbzip2 --best'
        ext.should == '.bz2'
      end
    end

    it 'should yield with the --fast option' do
      compressor.fast = true
      compressor.compress_with do |cmd, ext|
        cmd.should == 'pbzip2 --fast'
        ext.should == '.bz2'
      end
    end

    it 'should yield with the -p option' do
      compressor.processors = 2
      compressor.compress_with do |cmd, ext|
        cmd.should == 'pbzip2 -p2'
        ext.should == '.bz2'
      end
    end

    it 'should yield with the --best and --fast options' do
      compressor.best = true
      compressor.fast = true
      compressor.compress_with do |cmd, ext|
        cmd.should == 'pbzip2 --best --fast'
        ext.should == '.bz2'
      end
    end

    it 'should yield with the --best and -p options' do
      compressor.best = true
      compressor.processors = 2
      compressor.compress_with do |cmd, ext|
        cmd.should == 'pbzip2 --best -p2'
        ext.should == '.bz2'
      end
    end

    it 'should yield with the --fast and -p options' do
      compressor.fast = true
      compressor.processors = 2
      compressor.compress_with do |cmd, ext|
        cmd.should == 'pbzip2 --fast -p2'
        ext.should == '.bz2'
      end
    end

    it 'should yield with no options' do
      compressor.compress_with do |cmd, ext|
        cmd.should == 'pbzip2'
        ext.should == '.bz2'
      end
    end

  end # describe '#compress_with'

end
