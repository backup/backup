# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Compressor::Gzip do
  before do
    Backup::Compressor::Gzip.stubs(:utility).returns('gzip')
    Backup::Compressor::Gzip.instance_variable_set(:@has_rsyncable, true)
    Backup::Compressor::Gzip.any_instance.stubs(:utility).returns('gzip')
  end

  it 'should be a subclass of Compressor::Base' do
    Backup::Compressor::Gzip.
      superclass.should == Backup::Compressor::Base
  end

  it 'should be extended by Utilities::Helpers' do
    Backup::Compressor::Gzip.instance_eval('class << self; self; end').
        should include(Backup::Utilities::Helpers)
  end

  describe '.has_rsyncable?' do
    before do
      Backup::Compressor::Gzip.instance_variable_set(:@has_rsyncable, nil)
    end

    context 'when --rsyncable is available' do
      before do
        Backup::Compressor::Gzip.expects(:`).once.
            with('gzip --rsyncable --version >/dev/null 2>&1; echo $?').
            returns("0\n")
      end

      it 'returns true and caches the result' do
        Backup::Compressor::Gzip.has_rsyncable?.should be(true)
        Backup::Compressor::Gzip.has_rsyncable?.should be(true)
      end
    end

    context 'when --rsyncable is not available' do
      before do
        Backup::Compressor::Gzip.expects(:`).once.
            with('gzip --rsyncable --version >/dev/null 2>&1; echo $?').
            returns("1\n")
      end

      it 'returns false and caches the result' do
        Backup::Compressor::Gzip.has_rsyncable?.should be(false)
        Backup::Compressor::Gzip.has_rsyncable?.should be(false)
      end
    end
  end

  describe '#initialize' do
    let(:compressor) { Backup::Compressor::Gzip.new }

    after { Backup::Compressor::Gzip.clear_defaults! }

    context 'when no pre-configured defaults have been set' do
      it 'should use default values' do
        compressor.level.should be(false)
        compressor.rsyncable.should be(false)

        compressor.compress_with do |cmd, ext|
          cmd.should == 'gzip'
          ext.should == '.gz'
        end
      end

      it 'should use the values given' do
        compressor = Backup::Compressor::Gzip.new do |c|
          c.level = 5
          c.rsyncable = true
        end
        compressor.level.should == 5
        compressor.rsyncable.should be(true)

        compressor.compress_with do |cmd, ext|
          cmd.should == 'gzip -5 --rsyncable'
          ext.should == '.gz'
        end
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Compressor::Gzip.defaults do |c|
          c.level = 7
          c.rsyncable = true
        end
      end

      it 'should use pre-configured defaults' do
        compressor.level.should == 7
        compressor.rsyncable.should be(true)

        compressor.compress_with do |cmd, ext|
          cmd.should == 'gzip -7 --rsyncable'
          ext.should == '.gz'
        end
      end

      it 'should override pre-configured defaults' do
        compressor = Backup::Compressor::Gzip.new do |c|
          c.level = 6
          c.rsyncable = false
        end
        compressor.level.should == 6
        compressor.rsyncable.should be(false)

        compressor.compress_with do |cmd, ext|
          cmd.should == 'gzip -6'
          ext.should == '.gz'
        end
      end
    end # context 'when pre-configured defaults have been set'

    it 'should ignore rsyncable option and warn user if not supported' do
      Backup::Compressor::Gzip.instance_variable_set(:@has_rsyncable, false)

      Backup::Logger.expects(:warn).with() do |err|
        err.should be_a(Backup::Compressor::Gzip::Error)
        err.message.should match(/'rsyncable' option ignored/)
      end

      compressor = Backup::Compressor::Gzip.new do |c|
        c.level = 5
        c.rsyncable = true
      end
      compressor.level.should == 5
      compressor.rsyncable.should be(true)

      compressor.compress_with do |cmd, ext|
        cmd.should == 'gzip -5'
        ext.should == '.gz'
      end
    end
  end # describe '#initialize'

end
