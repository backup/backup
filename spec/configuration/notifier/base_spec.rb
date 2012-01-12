# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Notifier::Base do
  before do
    Backup::Configuration::Notifier::Base.defaults do |base|
      base.on_success = 'on_success'
      base.on_warning = 'on_warning'
      base.on_failure = 'on_failure'
    end
  end
  after { Backup::Configuration::Notifier::Base.clear_defaults! }

  it 'should set the default campfire configuration' do
    base = Backup::Configuration::Notifier::Base
    base.on_success.should == 'on_success'
    base.on_warning.should == 'on_warning'
    base.on_failure.should == 'on_failure'
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Notifier::Base.clear_defaults!

      base = Backup::Configuration::Notifier::Base
      base.on_success.should be_nil
      base.on_warning.should be_nil
      base.on_failure.should be_nil
    end
  end
end
