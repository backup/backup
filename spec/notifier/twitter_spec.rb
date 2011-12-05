# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Notifier::Twitter do
  let(:notifier) do
    Backup::Notifier::Twitter.new do |twitter|
      twitter.consumer_key       = 'consumer_key'
      twitter.consumer_secret    = 'consumer_secret'
      twitter.oauth_token        = 'oauth_token'
      twitter.oauth_token_secret = 'oauth_token_secret'
    end
  end

  describe '#initialize' do
    it 'sets the correct defaults' do
      notifier.consumer_key.should       == 'consumer_key'
      notifier.consumer_secret.should    == 'consumer_secret'
      notifier.oauth_token.should        == 'oauth_token'
      notifier.oauth_token_secret.should == 'oauth_token_secret'

      notifier.on_success.should == true
      notifier.on_warning.should == true
      notifier.on_failure.should == true
    end

    it 'uses and overrides configuration defaults' do
      Backup::Configuration::Notifier::Twitter.defaults do |twitter|
        twitter.consumer_key = 'new_consumer_key'
        twitter.on_success   = false
      end
      notifier = Backup::Notifier::Twitter.new do |twitter|
        twitter.consumer_key = 'my_own_consumer_key'
      end

      notifier.consumer_key.should   == 'my_own_consumer_key'
      notifier.on_success.should == false
      notifier.on_warning.should == true
      notifier.on_failure.should == true
    end

    it 'create a new Twitter::Client' do
      notifier.twitter_client.should be_an_instance_of ::Twitter::Client
      #notifier.twitter_client.credentials?.should be_true
      options = ::Twitter.options # v1.7.1 API
      options[:consumer_key].should       == notifier.consumer_key
      options[:consumer_secret].should    == notifier.consumer_secret
      options[:oauth_token].should        == notifier.oauth_token
      options[:oauth_token_secret].should == notifier.oauth_token_secret
    end
  end

  describe '#perform!' do
    let(:model)   { Backup::Model.new('trigger', 'label') {} }
    let(:message) { '[Backup::%s] label (trigger)' }

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
          notifier.twitter_client.expects(:update).with(message % 'Success')

          notifier.perform!(model)
        end
      end

      context 'when on_success is false' do
        it 'sends no message' do
          notifier.expects(:log!).never
          notifier.expects(:notify!).never
          notifier.twitter_client.expects(:update).never

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
          notifier.twitter_client.expects(:update).with(message % 'Warning')

          notifier.perform!(model)
        end
      end

      context 'when on_warning is true' do
        before { notifier.on_warning = true }

        it 'sends warning message' do
          notifier.expects(:log!)
          notifier.twitter_client.expects(:update).with(message % 'Warning')

          notifier.perform!(model)
        end
      end

      context 'when on_success and on_warning are false' do
        it 'sends no message' do
          notifier.expects(:log!).never
          notifier.expects(:notify!).never
          notifier.twitter_client.expects(:update).never

          notifier.perform!(model)
        end
      end

    end # context 'warning'

    context 'failure' do

      context 'when on_failure is true' do
        before { notifier.on_failure = true }

        it 'sends failure message' do
          notifier.expects(:log!)
          notifier.twitter_client.expects(:update).with(message % 'Failure')

          notifier.perform!(model, Exception.new)
        end
      end

      context 'when on_failure is false' do
        it 'sends no message' do
          notifier.expects(:log!).never
          notifier.expects(:notify!).never
          notifier.twitter_client.expects(:update).never

          notifier.perform!(model, Exception.new)
        end
      end

    end # context 'failure'

  end # describe '#perform!'
end
