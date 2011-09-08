# encoding: utf-8

require File.dirname(__FILE__) + '/../../spec_helper'

describe Backup::Configuration::Notifier::Twitter do
  before do
    Backup::Configuration::Notifier::Twitter.defaults do |tweet|
      tweet.consumer_key       = 'my_consumer_key'
      tweet.consumer_secret    = 'my_consumer_secret'
      tweet.oauth_token        = 'my_oauth_token'
      tweet.oauth_token_secret = 'my_oauth_token_secret'
    end
  end

  it 'should set the default tweet configuration' do
    tweet = Backup::Configuration::Notifier::Twitter
    tweet.consumer_key.should       == 'my_consumer_key'
    tweet.consumer_secret.should    == 'my_consumer_secret'
    tweet.oauth_token.should        == 'my_oauth_token'
    tweet.oauth_token_secret.should == 'my_oauth_token_secret'
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Notifier::Twitter.clear_defaults!

      tweet = Backup::Configuration::Notifier::Twitter
      tweet.consumer_key.should       == nil
      tweet.consumer_secret.should    == nil
      tweet.oauth_token.should        == nil
      tweet.oauth_token_secret.should == nil
    end
  end
end
