# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe 'Backup::Configuration::Helpers' do

  before do
    module Backup
      class Foo
        include Backup::Configuration::Helpers
        attr_accessor :accessor, :accessor_two
        attr_reader :reader

        attr_deprecate :removed,
                       :version => '1.1'

        attr_deprecate :removed_with_message,
                       :version => '1.2',
                       :message => 'This has no replacement.'

        attr_deprecate :removed_with_action,
                       :version => '1.3',
                       :action => lambda {|klass, val|
                         klass.accessor = val ? '1' : '0'
                         klass.accessor_two = 'updated'
                       }

        attr_deprecate :removed_with_action_and_message,
                       :version => '1.4',
                       :message => "Updating accessors.",
                       :action => lambda {|klass, val|
                         klass.accessor = val ? '1' : '0'
                         klass.accessor_two = 'updated'
                       }
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
      Backup::Foo.instance_variable_get(
          :@configuration).should be(configuration)
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
      Backup::Foo.deprecations.should be_a(Hash)
      Backup::Foo.deprecations.keys.count.should be(4)
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
      Backup::Foo.send(:attr_deprecate, :attr2,
                       :version => '2')
      Backup::Foo.send(:attr_deprecate, :attr3,
                       :version => '3',
                       :message => 'attr3 message')
      Backup::Foo.send(:attr_deprecate, :attr4,
                       :version => '4',
                       :message => 'attr4 message',
                       :action  => 'attr4 action')

      Backup::Foo.deprecations.should == {
        :attr1 => { :version => nil,
                    :message => nil,
                    :action  => nil },
        :attr2 => { :version => '2',
                    :message => nil,
                    :action  => nil },
        :attr3 => { :version => '3',
                    :message => 'attr3 message',
                    :action  => nil },
        :attr4 => { :version => '4',
                    :message => 'attr4 message',
                    :action  => 'attr4 action' }
      }
    end
  end

  describe '.log_deprecation_warning' do
    context 'when no message given' do
      it 'should log a warning that the attribute has been removed' do
        Backup::Logger.expects(:warn).with do |err|
          err.message.should ==
              "ConfigurationError: [DEPRECATION WARNING]\n" +
              "  Backup::Foo#removed has been deprecated as of backup v.1.1"
        end

        deprecation = Backup::Foo.deprecations[:removed]
        Backup::Foo.log_deprecation_warning(:removed, deprecation)
      end
    end

    context 'when a message is given' do
      it 'should log warning with the message' do
        Backup::Logger.expects(:warn).with do |err|
          err.message.should ==
              "ConfigurationError: [DEPRECATION WARNING]\n" +
              "  Backup::Foo#removed_with_message has been deprecated " +
              "as of backup v.1.2\n" +
              "  This has no replacement."
        end

        deprecation = Backup::Foo.deprecations[:removed_with_message]
        Backup::Foo.log_deprecation_warning(:removed_with_message, deprecation)

      end
    end
  end # describe '.log_deprecation_warning'

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

  describe '#method_missing' do
    context 'when the method is a deprecated method' do
      before do
        Backup::Logger.expects(:warn).with(
          instance_of(Backup::Errors::ConfigurationError)
        )
      end

      context 'when an :action is specified' do
        it 'should call the :action' do
          value = [true, false].shuffle.first
          expected_value = value ? '1' : '0'

          klass = Backup::Foo.new
          klass.removed_with_action = value

          klass.accessor.should == expected_value
          # lambda additionally sets :accessor_two
          klass.accessor_two.should == 'updated'
        end
      end

      context 'when no :action is specified' do
        it 'should only log the warning' do
          Backup::Foo.any_instance.expects(:accessor=).never

          klass = Backup::Foo.new
          klass.removed = 'foo'

          klass.accessor.should be_nil
        end
      end
    end

    context 'when the method is not a deprecated method' do
      it 'should raise a NoMethodError' do
        Backup::Logger.expects(:warn).never

        klass = Backup::Foo.new
        expect do
          klass.foobar = 'attr_value'
        end.to raise_error(NoMethodError)
      end
    end

    context 'when the method is not a set operation' do
      it 'should raise a NoMethodError' do
        Backup::Logger.expects(:warn).never

        klass = Backup::Foo.new
        expect do
          klass.removed
        end.to raise_error(NoMethodError)
      end
    end
  end # describe '#method_missing'
end
