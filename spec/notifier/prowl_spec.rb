# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Notifier::Prowl do
  let(:model) { Backup::Model.new(:test_trigger, 'test label') }
  let(:notifier) do
    Backup::Notifier::Prowl.new(model) do |prowl|
      prowl.application = 'application'
      prowl.api_key     = 'api_key'
    end
  end

  describe '#initialize' do
    it 'should sets the correct values' do
      notifier.application.should == 'application'
      notifier.api_key.should     == 'api_key'

      notifier.on_success.should == true
      notifier.on_warning.should == true
      notifier.on_failure.should == true
    end

    context 'when using configuration defaults' do
      after { Backup::Configuration::Notifier::Prowl.clear_defaults! }

      it 'should use the configuration defaults' do
        Backup::Configuration::Notifier::Prowl.defaults do |prowl|
          prowl.application = 'default_app'
          prowl.api_key     = 'default_api_key'

          prowl.on_success = false
          prowl.on_warning = false
          prowl.on_failure = false
        end
        notifier = Backup::Notifier::Prowl.new(model)
        notifier.application.should == 'default_app'
        notifier.api_key.should     == 'default_api_key'

        notifier.on_success.should == false
        notifier.on_warning.should == false
        notifier.on_failure.should == false
      end

      it 'should override the configuration defaults' do
        Backup::Configuration::Notifier::Prowl.defaults do |prowl|
          prowl.application = 'old_app'
          prowl.api_key     = 'old_api_key'

          prowl.on_success = true
          prowl.on_warning = false
          prowl.on_failure = false
        end
        notifier = Backup::Notifier::Prowl.new(model) do |prowl|
          prowl.application = 'new_app'
          prowl.api_key     = 'new_api_key'

          prowl.on_success = false
          prowl.on_warning = true
          prowl.on_failure = true
        end

        notifier.application.should == 'new_app'
        notifier.api_key.should     == 'new_api_key'

        notifier.on_success.should == false
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end
    end # context 'when using configuration defaults'
  end

  describe '#notify!' do
    context 'when status is :success' do
      it 'should send Success message' do
        notifier.expects(:send_message).with(
          '[Backup::Success]'
        )
        notifier.send(:notify!, :success)
      end
    end

    context 'when status is :warning' do
      it 'should send Warning message' do
        notifier.expects(:send_message).with(
          '[Backup::Warning]'
        )
        notifier.send(:notify!, :warning)
      end
    end

    context 'when status is :failure' do
      it 'should send Failure message' do
        notifier.expects(:send_message).with(
          '[Backup::Failure]'
        )
        notifier.send(:notify!, :failure)
      end
    end
  end # describe '#notify!'

  describe '#send_message' do
    it 'should send the given message' do
      client = mock
      Prowler.expects(:new).with(
        :application => 'application', :api_key => 'api_key'
      ).returns(client)
      client.expects(:notify).with(
        'a message',
        'test label (test_trigger)'
      )

      notifier.send(:send_message, 'a message')
    end
  end

end
