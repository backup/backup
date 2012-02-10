# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Notifier::Prowl do
  before do
    Backup::Configuration::Notifier::Prowl.defaults do |prowl|
      prowl.application = 'my_application'
      prowl.api_key     = 'my_api_key'
    end
  end
  after { Backup::Configuration::Notifier::Prowl.clear_defaults! }

  it 'should set the default tweet configuration' do
    prowl = Backup::Configuration::Notifier::Prowl
    prowl.application.should == 'my_application'
    prowl.api_key.should     == 'my_api_key'
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Notifier::Prowl.clear_defaults!

      prowl = Backup::Configuration::Notifier::Prowl
      prowl.application.should == nil
      prowl.api_key.should     == nil
    end
  end
end
