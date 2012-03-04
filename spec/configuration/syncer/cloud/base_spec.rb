# encoding: utf-8

require File.expand_path('../../../../spec_helper.rb', __FILE__)

describe 'Backup::Configuration::Syncer::Cloud::Base' do
  it 'should be a subclass of Syncer::Base' do
    cloud = Backup::Configuration::Syncer::Cloud::Base
    cloud.superclass.should == Backup::Configuration::Syncer::Base
  end

  before do
    Backup::Configuration::Syncer::Cloud::Base.defaults do |cloud|
      cloud.concurrency_type    = 'default_type'
      cloud.concurrency_level   = 'default_level'
    end
  end
  after { Backup::Configuration::Syncer::Cloud::Base.clear_defaults! }

  it 'should set the default cloud files configuration' do
    cloud = Backup::Configuration::Syncer::Cloud::Base
    cloud.concurrency_type.should   == 'default_type'
    cloud.concurrency_level.should  == 'default_level'
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Syncer::Cloud::Base.clear_defaults!

      cloud = Backup::Configuration::Syncer::Cloud::Base
      cloud.concurrency_type.should   == nil
      cloud.concurrency_level.should  == nil
    end
  end
end
