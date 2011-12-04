# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Notifier::Hipchat do
  before do
    Backup::Configuration::Notifier::Hipchat.defaults do |hipchat|
      hipchat.token          = 'token'
      hipchat.from           = 'DB Backup'
      hipchat.rooms_notified = ['activity']
      hipchat.success_color  = 'green'
      hipchat.failure_color  = 'red'
    end
  end

  it 'should set the default tweet configuration' do
    hipchat = Backup::Configuration::Notifier::Hipchat
    hipchat.token.should          == 'token'
    hipchat.from.should           == 'DB Backup'
    hipchat.rooms_notified.should == ['activity']
    hipchat.success_color.should  == 'green'
    hipchat.failure_color.should  == 'red'
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Notifier::Hipchat.clear_defaults!

      hipchat = Backup::Configuration::Notifier::Hipchat
      hipchat.token.should          == nil
      hipchat.from.should           == nil
      hipchat.rooms_notified.should == nil
      hipchat.success_color.should  == nil
      hipchat.failure_color.should  == nil
    end
  end
end
