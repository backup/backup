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
end
