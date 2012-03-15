# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe 'Backup::Configuration::Helpers' do

  before do
    module Backup
      class Foo
        include Backup::Configuration::Helpers
        attr_accessor :accessor
        attr_reader :reader
        attr_deprecate :removed_accessor, :version => '1.1'
        attr_deprecate :replaced_accessor, :version => '1.2',
                       :replacement => :accessor
      end
    end
  end

  after do
    Backup.send(:remove_const, 'Foo')
  end

  describe '.defaults' do
    let(:configuration) { mock }

    before do
      Backup::Configuration::Store.expects(:new).once.returns(configuration)
    end

    it 'should return the Configuration::Store for the class' do
      Backup::Foo.defaults.should be(configuration)
    end

    it 'should yield the Configuration::Store for the class' do
      Backup::Foo.defaults do |config|
        config.should be(configuration)
      end
    end

    it 'should cache the Configuration::Store for the class' do
      Backup::Foo.instance_variable_get(:@configuration).should be_nil
      Backup::Foo.defaults.should be(configuration)
      Backup::Foo.instance_variable_get(:@configuration).should be(configuration)
      Backup::Foo.defaults.should be(configuration)
    end
  end

  describe '.clear_defaults!' do
    it 'should clear all defaults set' do
      Backup::Foo.defaults do |config|
        config.accessor = 'foo'
      end
      Backup::Foo.defaults.accessor.should == 'foo'

      Backup::Foo.clear_defaults!
      Backup::Foo.defaults.accessor.should be_nil
    end
  end

  describe '.deprecations' do
    it 'should return @deprecations' do
      Backup::Foo.deprecations.should == {
        :removed_accessor  => { :version => '1.1', :replacement => nil },
        :replaced_accessor => { :version => '1.2', :replacement => :accessor }
      }
    end

    it 'should set @deprecations to an empty hash if not set' do
      Backup::Foo.send(:remove_instance_variable, :@deprecations)
      Backup::Foo.deprecations.should == {}
    end
  end

  describe '.attr_deprecate' do
    before do
      Backup::Foo.send(:remove_instance_variable, :@deprecations)
    end

    it 'should add deprected attributes' do
      Backup::Foo.send(:attr_deprecate, :attr1)
      Backup::Foo.send(:attr_deprecate, :attr2, :version => '1.3')
      Backup::Foo.send(:attr_deprecate, :attr3, :replacement => :foo)
      Backup::Foo.send(:attr_deprecate, :attr4,
                       :version => '1.4', :replacement => :foobar)

      Backup::Foo.deprecations.should == {
        :attr1 => { :version => nil,    :replacement => nil },
        :attr2 => { :version => '1.3',  :replacement => nil },
        :attr3 => { :version => nil,    :replacement => :foo },
        :attr4 => { :version => '1.4',  :replacement => :foobar }
      }
    end
  end

  describe '.log_deprecation_warning' do
    context 'when a replacement is specified' do
      it 'should log a warning that the attribute has been removed' do
        Backup::Logger.expects(:warn).with do |err|
          err.message.should ==
              "ConfigurationError: [DEPRECATION WARNING]\n" +
              "  Backup::Foo.removed_accessor has been deprecated as of backup v.1.1"
        end

        deprecation = Backup::Foo.deprecations[:removed_accessor]
        Backup::Foo.log_deprecation_warning(:removed_accessor, deprecation)
      end
    end

    context 'when no replacement is specified' do
      it 'should log a warning that the attribute has been replaced' do
        Backup::Logger.expects(:warn).with do |err|
          err.message.should ==
              "ConfigurationError: [DEPRECATION WARNING]\n" +
              "  Backup::Foo.replaced_accessor has been deprecated as of backup v.1.2\n" +
              "  This setting has been replaced with:\n" +
              "  Backup::Foo.accessor"
        end

        deprecation = Backup::Foo.deprecations[:replaced_accessor]
        Backup::Foo.log_deprecation_warning(:replaced_accessor, deprecation)
      end
    end
  end

  describe '#load_defaults!' do
    let(:klass) { Backup::Foo.new }

    it 'should load default values set for the class' do
      Backup::Foo.defaults do |config|
        config.accessor = 'foo'
      end

      klass.send(:load_defaults!)
      klass.accessor.should == 'foo'
    end

    it 'should raise an error if defaults are set for attribute readers' do
      Backup::Foo.defaults do |config|
        config.reader = 'foo'
      end

      expect do
        klass.send(:load_defaults!)
      end.to raise_error(NoMethodError, /Backup::Foo/)
    end

    it 'should raise an error if defaults were set for invalid accessors' do
      Backup::Foo.defaults do |config|
        config.foobar = 'foo'
      end

      expect do
        klass.send(:load_defaults!)
      end.to raise_error(NoMethodError, /Backup::Foo/)
    end
  end

  describe '#missing_method' do
    describe 'instantiating a class when defaults have been set' do
      context 'when the missing method is an attribute set operator' do
        context 'and the method has been deprecated' do
          context 'and the deprecated method has a replacement' do
            it 'should set the value on the replacement and log a warning' do
              Backup::Foo.defaults do |f|
                f.replaced_accessor = 'attr_value'
              end

              Backup::Logger.expects(:warn)

              klass = Backup::Foo.new
              klass.send(:load_defaults!)
              klass.accessor.should == 'attr_value'
            end
          end

          context 'and the deprecated method has no replacement' do
            it 'should only log a warning' do
              Backup::Foo.defaults do |f|
                f.removed_accessor = 'attr_value'
              end

              Backup::Logger.expects(:warn)

              klass = Backup::Foo.new
              klass.send(:load_defaults!)
              klass.accessor.should be_nil
            end
          end
        end

        context 'and the method is not a deprecated method' do
          it 'should raise a NoMethodError' do
            Backup::Foo.defaults do |f|
              f.foobar = 'attr_value'
            end

            Backup::Logger.expects(:warn).never

            klass = Backup::Foo.new
            expect do
              klass.send(:load_defaults!)
            end.to raise_error(NoMethodError)
          end
        end
      end
    end # describe 'instantiating a class when defaults have been set'

    describe 'instantiating a new class and directly setting values' do
      context 'when the missing method is an attribute set operator' do
        context 'and the method has been deprecated' do
          context 'and the deprecated method has a replacement' do
            it 'should set the value on the replacement and log a warning' do
              Backup::Logger.expects(:warn)

              klass = Backup::Foo.new
              klass.replaced_accessor = 'attr_value'
              klass.accessor.should == 'attr_value'
            end
          end

          context 'and the deprecated method has no replacement' do
            it 'should only log a warning' do
              Backup::Logger.expects(:warn)

              klass = Backup::Foo.new
              klass.removed_accessor = 'attr_value'
              klass.accessor.should be_nil
            end
          end
        end

        context 'and the method is not a deprecated method' do
          it 'should raise a NoMethodError' do
            Backup::Logger.expects(:warn).never

            klass = Backup::Foo.new
            expect do
              klass.foobar = 'attr_value'
            end.to raise_error(NoMethodError)
          end
        end
      end

      context 'when the missing method is not a set operation' do
        it 'should raise a NoMethodError' do
          Backup::Logger.expects(:warn).never

          klass = Backup::Foo.new
          expect do
            klass.removed_accessor
          end.to raise_error(NoMethodError)
        end
      end
    end # describe 'instantiating a new class and directly setting values'
  end

end
