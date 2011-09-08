# encoding: utf-8

require File.dirname(__FILE__) + '/../../spec_helper'

describe Backup::Configuration::Notifier::Campfire do
  before do
    Backup::Configuration::Notifier::Campfire.defaults do |campfire|
      campfire.api_token = 'my_api_authentication_token'
      campfire.subdomain = 'my_subdomain'
      campfire.room_id   = 'my_room_id'
    end
  end

  it 'should set the default campfire configuration' do
    campfire = Backup::Configuration::Notifier::Campfire
    campfire.api_token.should == 'my_api_authentication_token'
    campfire.subdomain.should == 'my_subdomain'
    campfire.room_id.should   == 'my_room_id'
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Notifier::Campfire.clear_defaults!

      campfire = Backup::Configuration::Notifier::Campfire
      campfire.api_token.should == nil
      campfire.subdomain.should == nil
      campfire.room_id.should   == nil
    end
  end
end
