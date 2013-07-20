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

  describe 'deprecations' do
    describe 'fast and best options' do
      context 'when only the fast option is used' do
        before do
          Backup::Logger.expects(:warn).with {|err|
            err.should be_an_instance_of Backup::Configuration::Error
            err.message.should match(
              /Use Gzip#level instead/
            )
          }
        end

        context 'when set to true' do
          it 'should log a warning and set `level` to 1' do
            compressor = Backup::Compressor::Gzip.new do |c|
              c.fast = true
            end
            compressor.level.should == 1
          end
        end

        context 'when set to false' do
          it 'should only log a warning' do
            compressor = Backup::Compressor::Gzip.new do |c|
              c.fast = false
            end
            compressor.level.should be_false
          end
        end
      end

      context 'when only the best option is used' do
        before do
          Backup::Logger.expects(:warn).with {|err|
            err.should be_an_instance_of Backup::Configuration::Error
            err.message.should match(
              /Use Gzip#level instead/
            )
          }
        end

        context 'when set to true' do
          it 'should log a warning and set `level` to 1' do
            compressor = Backup::Compressor::Gzip.new do |c|
              c.best = true
            end
            compressor.level.should == 9
          end
        end

        context 'when set to false' do
          it 'should only log a warning' do
            compressor = Backup::Compressor::Gzip.new do |c|
              c.best = false
            end
            compressor.level.should be_false
          end
        end

      end

      context 'when both fast and best options are used' do
        before do
          Backup::Logger.expects(:warn).twice.with {|err|
            err.should be_an_instance_of Backup::Configuration::Error
            err.message.should match(
              /Use Gzip#level instead/
            )
          }
        end

        context 'when both are set true' do
          context 'when fast is set first' do
            it 'should cause the best option to be set' do
              compressor = Backup::Compressor::Gzip.new do |c|
                c.fast = true
                c.best = true
              end
              compressor.level.should == 9
            end
          end

          context 'when best is set first' do
            it 'should cause the fast option to be set' do
              compressor = Backup::Compressor::Gzip.new do |c|
                c.best = true
                c.fast = true
              end
              compressor.level.should == 1
            end
          end
        end

        context 'when only one is set true' do
          context 'when fast is set true before best' do
            it 'should cause the fast option to be set' do
              compressor = Backup::Compressor::Gzip.new do |c|
                c.fast = true
                c.best = false
              end
              compressor.level.should == 1
            end
          end

          context 'when fast is set true after best' do
            it 'should cause the fast option to be set' do
              compressor = Backup::Compressor::Gzip.new do |c|
                c.best = false
                c.fast = true
              end
              compressor.level.should == 1
            end
          end

          context 'when best is set true before fast' do
            it 'should cause the best option to be set' do
              compressor = Backup::Compressor::Gzip.new do |c|
                c.best = true
                c.fast = false
              end
              compressor.level.should == 9
            end
          end

          context 'when best is set true after fast' do
            it 'should cause the best option to be set' do
              compressor = Backup::Compressor::Gzip.new do |c|
                c.fast = false
                c.best = true
              end
              compressor.level.should == 9
            end
          end
        end

        context 'when both are set false' do
          it 'should only issue the two warnings' do
            compressor = Backup::Compressor::Gzip.new do |c|
              c.fast = false
              c.best = false
            end
            compressor.level.should be_false
          end
        end
      end
    end # describe 'fast and best options'
  end # describe 'deprecations'
end
