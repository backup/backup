# encoding: utf-8

require File.expand_path('../../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Syncer::RSync::Base do
  before do
    Backup::Configuration::Syncer::RSync::Base.defaults do |rsync|
      rsync.additional_options  = ['foo']
    end
  end
  after { Backup::Configuration::Syncer::RSync::Base.clear_defaults! }

  it 'should set the default rsync configuration' do
    rsync = Backup::Configuration::Syncer::RSync::Base
    rsync.additional_options.should == ['foo']
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Syncer::RSync::Base.clear_defaults!

      rsync = Backup::Configuration::Syncer::RSync::Base
      rsync.additional_options.should == nil
    end
  end
end
