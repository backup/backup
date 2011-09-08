# encoding: utf-8

require File.dirname(__FILE__) + '/../../spec_helper'

describe Backup::Configuration::Notifier::Presently do
  before do
    Backup::Configuration::Notifier::Presently.defaults do |presently|
      presently.subdomain = 'my_subdomain'
      presently.user_name = 'my_user_name'
      presently.password  = 'my_password'
      presently.group_id  = 'my_group_id'
    end
  end

  it 'should set the default tweet configuration' do
    presently = Backup::Configuration::Notifier::Presently
    presently.subdomain.should == 'my_subdomain'
    presently.user_name.should == 'my_user_name'
    presently.password.should  == 'my_password'
    presently.group_id.should  == 'my_group_id'
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Notifier::Presently.clear_defaults!

      presently = Backup::Configuration::Notifier::Presently
      presently.subdomain.should == nil
      presently.user_name.should == nil
      presently.password.should  == nil
      presently.group_id.should  == nil
    end
  end
end
