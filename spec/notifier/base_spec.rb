# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe 'Backup::Notifier::Base' do
  let(:model) { Backup::Model.new(:test_trigger, 'test label') }
  let(:notifier) { Backup::Notifier::Base.new(model) }

  describe '#initialize' do

    it "sets the correct defaults" do
      notifier.on_success.should == true
      notifier.on_warning.should == true
      notifier.on_failure.should == true
    end

    context 'when using configuration defaults' do
      after { Backup::Configuration::Notifier::Base.clear_defaults! }

      it 'uses configuration defaults' do
        Backup::Configuration::Notifier::Base.defaults do |notifier|
          notifier.on_success = false
          notifier.on_warning = false
          notifier.on_failure = false
        end

        base = Backup::Notifier::Base.new(model)
        base.on_success.should == false
        base.on_warning.should == false
        base.on_failure.should == false
      end
    end

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
