# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe 'Backup::Notifier::Base' do
  let(:model) { Backup::Model.new(:test_trigger, 'test label') }
  let(:notifier) { Backup::Notifier::Base.new(model) }

  it 'should include Configuration::Helpers' do
    Backup::Notifier::Base.
      include?(Backup::Configuration::Helpers).should be_true
  end

  describe '#initialize' do
    after { Backup::Notifier::Base.clear_defaults! }

    it 'should load pre-configured defaults' do
      Backup::Notifier::Base.any_instance.expects(:load_defaults!)
      notifier
    end

    it 'should set a reference to the model' do
      notifier.instance_variable_get(:@model).should == model
    end

    context 'when no pre-configured defaults have been set' do
      it 'should set default values' do
        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Notifier::Base.defaults do |n|
          n.on_success = false
          n.on_warning = false
          n.on_failure = false
        end
      end

      it 'should use pre-configured defaults' do
        notifier.on_success.should be_false
        notifier.on_warning.should be_false
        notifier.on_failure.should be_false
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#perform!' do
    before do
      notifier.expects(:log!)
      Backup::Template.expects(:new).with({:model => model})
    end

    context 'when failure is false' do
      context 'when no warnings were issued' do
        before do
          Backup::Logger.expects(:has_warnings?).returns(false)
        end

        it 'should call #notify! with :success' do
          notifier.expects(:notify!).with(:success)
          notifier.perform!
        end
      end

      context 'when warnings were issued' do
        before do
          Backup::Logger.expects(:has_warnings?).returns(true)
        end

        it 'should call #notify! with :warning' do
          notifier.expects(:notify!).with(:warning)
          notifier.perform!
        end
      end
    end # context 'when failure is false'

    context 'when failure is true' do
      it 'should call #notify with :failure' do
        notifier.expects(:notify!).with(:failure)
        notifier.perform!(true)
      end
    end
  end # describe '#perform!'

  describe '#notifier_name' do
    it 'should return class name without Backup:: namespace' do
      notifier.send(:notifier_name).should == 'Notifier::Base'
    end
  end

  describe '#log!' do
    it 'should log a message' do
      Backup::Logger.expects(:message).with(
        "Notifier::Base started notifying about the process."
      )
      notifier.send(:log!)
    end
  end

end
