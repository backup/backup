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

  it do
    notifier.consumer_key.should       == 'consumer_key'
    notifier.consumer_secret.should    == 'consumer_secret'
    notifier.oauth_token.should        == 'oauth_token'
    notifier.oauth_token_secret.should == 'oauth_token_secret'

    notifier.on_success.should == true
    notifier.on_failure.should == true
  end

  describe 'defaults' do
    it do
      Backup::Configuration::Notifier::Twitter.defaults do |twitter|
        twitter.consumer_key = 'new_consumer_key'
        twitter.on_success   = false
        twitter.on_failure   = true
      end
      notifier = Backup::Notifier::Twitter.new do |twitter|
        twitter.consumer_key = 'my_own_consumer_key'
      end

      notifier.consumer_key.should   == 'my_own_consumer_key'
      notifier.on_success.should == false
      notifier.on_failure.should == true
    end
  end

  describe '#initialize' do
    it do
      Backup::Notifier::Twitter.any_instance.expects(:set_defaults!)
      Backup::Notifier::Twitter.new
    end
  end

  describe '#perform!' do
    let(:model) { Backup::Model.new('blah', 'blah') {} }
    before do
      notifier.on_success = false
      notifier.on_failure = false
    end

    context "when successful" do
      it do
        Backup::Logger.expects(:message).with("Backup::Notifier::Twitter started notifying about the process.")
        notifier.expects("notify_success!")
        notifier.on_success = true
        notifier.perform!(model)
      end

      it do
        notifier.expects("notify_success!").never
        notifier.on_success = false
        notifier.perform!(model)
      end
    end

    context "when failed" do
      it do
        Backup::Logger.expects(:message).with("Backup::Notifier::Twitter started notifying about the process.")
        notifier.expects("notify_failure!")
        notifier.on_failure = true
        notifier.perform!(model, Exception.new)
      end

      it do
        notifier.expects("notify_failure!").never
        notifier.on_failure = false
        notifier.perform!(model, Exception.new)
      end
    end
  end
end
