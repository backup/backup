# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Compressor::Bzip2 do
  before do
    Backup::Compressor::Bzip2.any_instance.stubs(:utility).returns('bzip2')
  end

  it 'should be a subclass of Compressor::Base' do
    Backup::Compressor::Bzip2.
      superclass.should == Backup::Compressor::Base
  end

  describe '#initialize' do
    let(:compressor) { Backup::Compressor::Bzip2.new }

    after { Backup::Compressor::Bzip2.clear_defaults! }

    it 'should load pre-configured defaults' do
      Backup::Compressor::Bzip2.any_instance.expects(:load_defaults!)
      compressor
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use default values' do
        compressor.level.should be_false

        compressor.instance_variable_get(:@cmd).should == 'bzip2'
        compressor.instance_variable_get(:@ext).should == '.bz2'
      end

      it 'should use the values given' do
        compressor = Backup::Compressor::Bzip2.new do |c|
          c.level = 5
        end
        compressor.level.should == 5

        compressor.instance_variable_get(:@cmd).should == 'bzip2 -5'
        compressor.instance_variable_get(:@ext).should == '.bz2'
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Compressor::Bzip2.defaults do |c|
          c.level = 7
        end
      end

      it 'should use pre-configured defaults' do
        compressor.level.should == 7

        compressor.instance_variable_get(:@cmd).should == 'bzip2 -7'
        compressor.instance_variable_get(:@ext).should == '.bz2'
      end

      it 'should override pre-configured defaults' do
        compressor = Backup::Compressor::Bzip2.new do |c|
          c.level = 6
        end
        compressor.level.should == 6

        compressor.instance_variable_get(:@cmd).should == 'bzip2 -6'
        compressor.instance_variable_get(:@ext).should == '.bz2'
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe 'deprecations' do
    describe 'fast and best options' do
      context 'when only the fast option is used' do
        before do
          Backup::Logger.expects(:warn).with {|err|
            err.should be_an_instance_of Backup::Errors::ConfigurationError
            err.message.should match(
              /Use Bzip2#level instead/
            )
          }
        end

        context 'when set to true' do
          it 'should log a warning and set `level` to 1' do
            compressor = Backup::Compressor::Bzip2.new do |c|
              c.fast = true
            end
            compressor.level.should == 1
          end
        end

        context 'when set to false' do
          it 'should only log a warning' do
            compressor = Backup::Compressor::Bzip2.new do |c|
              c.fast = false
            end
            compressor.level.should be_false
          end
        end
      end

      context 'when only the best option is used' do
        before do
          Backup::Logger.expects(:warn).with {|err|
            err.should be_an_instance_of Backup::Errors::ConfigurationError
            err.message.should match(
              /Use Bzip2#level instead/
            )
          }
        end

        context 'when set to true' do
          it 'should log a warning and set `level` to 1' do
            compressor = Backup::Compressor::Bzip2.new do |c|
              c.best = true
            end
            compressor.level.should == 9
          end
        end

        context 'when set to false' do
          it 'should only log a warning' do
            compressor = Backup::Compressor::Bzip2.new do |c|
              c.best = false
            end
            compressor.level.should be_false
          end
        end

      end

      context 'when both fast and best options are used' do
        before do
          Backup::Logger.expects(:warn).twice.with {|err|
            err.should be_an_instance_of Backup::Errors::ConfigurationError
            err.message.should match(
              /Use Bzip2#level instead/
            )
          }
        end

        context 'when both are set true' do
          context 'when fast is set first' do
            it 'should cause the best option to be set' do
              compressor = Backup::Compressor::Bzip2.new do |c|
                c.fast = true
                c.best = true
              end
              compressor.level.should == 9
            end
          end

          context 'when best is set first' do
            it 'should cause the fast option to be set' do
              compressor = Backup::Compressor::Bzip2.new do |c|
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
              compressor = Backup::Compressor::Bzip2.new do |c|
                c.fast = true
                c.best = false
              end
              compressor.level.should == 1
            end
          end

          context 'when fast is set true after best' do
            it 'should cause the fast option to be set' do
              compressor = Backup::Compressor::Bzip2.new do |c|
                c.best = false
                c.fast = true
              end
              compressor.level.should == 1
            end
          end

          context 'when best is set true before fast' do
            it 'should cause the best option to be set' do
              compressor = Backup::Compressor::Bzip2.new do |c|
                c.best = true
                c.fast = false
              end
              compressor.level.should == 9
            end
          end

          context 'when best is set true after fast' do
            it 'should cause the best option to be set' do
              compressor = Backup::Compressor::Bzip2.new do |c|
                c.fast = false
                c.best = true
              end
              compressor.level.should == 9
            end
          end
        end

        context 'when both are set false' do
          it 'should only issue the two warnings' do
            compressor = Backup::Compressor::Bzip2.new do |c|
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
