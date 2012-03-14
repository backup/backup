# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Notifier::Twitter do
  let(:model) { Backup::Model.new(:test_trigger, 'test label') }
  let(:notifier) do
    Backup::Notifier::Twitter.new(model) do |twitter|
      twitter.consumer_key       = 'consumer_key'
      twitter.consumer_secret    = 'consumer_secret'
      twitter.oauth_token        = 'oauth_token'
      twitter.oauth_token_secret = 'oauth_token_secret'
    end
  end

  it 'should be a subclass of Notifier::Base' do
    Backup::Notifier::Twitter.
      superclass.should == Backup::Notifier::Base
  end

  describe '#initialize' do
    after { Backup::Notifier::Twitter.clear_defaults! }

    it 'should load pre-configured defaults through Base' do
      Backup::Notifier::Twitter.any_instance.expects(:load_defaults!)
      notifier
    end

    it 'should pass the model reference to Base' do
      notifier.instance_variable_get(:@model).should == model
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use the values given' do
        notifier.consumer_key.should       == 'consumer_key'
        notifier.consumer_secret.should    == 'consumer_secret'
        notifier.oauth_token.should        == 'oauth_token'
        notifier.oauth_token_secret.should == 'oauth_token_secret'

        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end

      it 'should use default values if none are given' do
        notifier = Backup::Notifier::Twitter.new(model)
        notifier.consumer_key.should       be_nil
        notifier.consumer_secret.should    be_nil
        notifier.oauth_token.should        be_nil
        notifier.oauth_token_secret.should be_nil

        notifier.on_success.should == true
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Notifier::Twitter.defaults do |n|
          n.consumer_key       = 'some_consumer_key'
          n.consumer_secret    = 'some_consumer_secret'
          n.oauth_token        = 'some_oauth_token'
          n.oauth_token_secret = 'some_oauth_token_secret'

          n.on_success = false
          n.on_warning = false
          n.on_failure = false
        end
      end

      it 'should use pre-configured defaults' do
        notifier = Backup::Notifier::Twitter.new(model)
        notifier.consumer_key.should       == 'some_consumer_key'
        notifier.consumer_secret.should    == 'some_consumer_secret'
        notifier.oauth_token.should        == 'some_oauth_token'
        notifier.oauth_token_secret.should == 'some_oauth_token_secret'

        notifier.on_success.should == false
        notifier.on_warning.should == false
        notifier.on_failure.should == false
      end

      it 'should override pre-configured defaults' do
        notifier = Backup::Notifier::Twitter.new(model) do |n|
          n.consumer_key       = 'new_consumer_key'
          n.consumer_secret    = 'new_consumer_secret'
          n.oauth_token        = 'new_oauth_token'
          n.oauth_token_secret = 'new_oauth_token_secret'

          n.on_success = false
          n.on_warning = true
          n.on_failure = true
        end

        notifier.consumer_key.should       == 'new_consumer_key'
        notifier.consumer_secret.should    == 'new_consumer_secret'
        notifier.oauth_token.should        == 'new_oauth_token'
        notifier.oauth_token_secret.should == 'new_oauth_token_secret'

        notifier.on_success.should == false
        notifier.on_warning.should == true
        notifier.on_failure.should == true
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'

  describe '#notify!' do
    context 'when status is :success' do
      it 'should send Success message' do
        notifier.expects(:send_message).with(
          "[Backup::Success] test label (test_trigger) (@ #{notifier.instance_variable_get("@model").time})"
        )
        notifier.send(:notify!, :success)
      end
    end

    context 'when status is :warning' do
      it 'should send Warning message' do
        notifier.expects(:send_message).with(
          "[Backup::Warning] test label (test_trigger) (@ #{notifier.instance_variable_get("@model").time})"
        )
        notifier.send(:notify!, :warning)
      end
    end

    context 'when status is :failure' do
      it 'should send Failure message' do
        notifier.expects(:send_message).with(
          "[Backup::Failure] test label (test_trigger) (@ #{notifier.instance_variable_get("@model").time})"
        )
        notifier.send(:notify!, :failure)
      end
    end
  end # describe '#notify!'

  describe '#send_message' do
    it 'should send a message' do
      client, config = mock, mock

      ::Twitter.expects(:configure).yields(config)
      config.expects(:consumer_key=).with('consumer_key')
      config.expects(:consumer_secret=).with('consumer_secret')
      config.expects(:oauth_token=).with('oauth_token')
      config.expects(:oauth_token_secret=).with('oauth_token_secret')

      ::Twitter::Client.expects(:new).returns(client)
      client.expects(:update).with('a message')

      notifier.send(:send_message, 'a message')
    end
  end
end
