# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Notifier::Prowl do
  let(:notifier) do
    Backup::Notifier::Prowl.new do |prowl|
      prowl.application = 'application'
      prowl.api_key     = 'api_key'
    end
  end

  describe '#initialize' do
    it 'sets the correct defaults' do
      notifier.application = 'application'
      notifier.api_key     = 'api_key'

      notifier.on_success.should == true
      notifier.on_warning.should == true
      notifier.on_failure.should == true
    end

    it 'uses and overrides configuration defaults' do
      Backup::Configuration::Notifier::Prowl.defaults do |notifier|
        notifier.application  = 'my_default_application'
        notifier.on_success   = false
      end
      prowl = Backup::Notifier::Prowl.new do |notifier|
        notifier.api_key = 'my_own_api_key'
      end

      prowl.application.should == 'my_default_application'
      prowl.api_key.should     == 'my_own_api_key'
      prowl.on_success.should  == false
      prowl.on_warning.should  == true
      prowl.on_failure.should  == true
    end

    it 'creates a new Prowler::Application' do
      notifier.prowl_client.should be_an_instance_of Prowler::Application
      notifier.prowl_client.application.should == notifier.application
      notifier.prowl_client.api_key.should == notifier.api_key
    end
  end

  describe '#perform!' do
    let(:model)     { Backup::Model.new('trigger', 'label') {} }
    let(:message_a) { '[Backup::%s]' }
    let(:message_b) { 'label (trigger)' }

    before do
      notifier.on_success = false
      notifier.on_warning = false
      notifier.on_failure = false
    end

    context 'success' do

      context 'when on_success is true' do
        before { notifier.on_success = true }

        it 'sends success message' do
          notifier.expects(:log!)
          notifier.prowl_client.expects(:notify).
              with(message_a % 'Success', message_b)

          notifier.perform!(model)
        end
      end

      context 'when on_success is false' do
        it 'sends no message' do
          notifier.expects(:log!).never
          notifier.expects(:notify!).never
          notifier.prowl_client.expects(:notify).never

          notifier.perform!(model)
        end
      end

    end # context 'success'

    context 'warning' do
      before { Backup::Logger.stubs(:has_warnings?).returns(true) }

      context 'when on_success is true' do
        before { notifier.on_success = true }

        it 'sends warning message' do
          notifier.expects(:log!)
          notifier.prowl_client.expects(:notify).
              with(message_a % 'Warning', message_b)

          notifier.perform!(model)
        end
      end

      context 'when on_warning is true' do
        before { notifier.on_warning = true }

        it 'sends warning message' do
          notifier.expects(:log!)
          notifier.prowl_client.expects(:notify).
              with(message_a % 'Warning', message_b)

          notifier.perform!(model)
        end
      end

      context 'when on_success and on_warning are false' do
        it 'sends no message' do
          notifier.expects(:log!).never
          notifier.expects(:notify!).never
          notifier.prowl_client.expects(:notify).never

          notifier.perform!(model)
        end
      end

    end # context 'warning'

    context 'failure' do

      context 'when on_failure is true' do
        before { notifier.on_failure = true }

        it 'sends failure message' do
          notifier.expects(:log!)
          notifier.prowl_client.expects(:notify).
              with(message_a % 'Failure', message_b)

          notifier.perform!(model, Exception.new)
        end
      end

      context 'when on_failure is false' do
        it 'sends no message' do
          notifier.expects(:log!).never
          notifier.expects(:notify!).never
          notifier.prowl_client.expects(:notify).never

          notifier.perform!(model, Exception.new)
        end
      end

    end # context 'failure'

  end # describe '#perform!'
end
