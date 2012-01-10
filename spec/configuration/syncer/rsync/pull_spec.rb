# encoding: utf-8

require File.expand_path('../../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Syncer::RSync::Pull do
  it 'should be a subclass of RSync::Push' do
    rsync = Backup::Configuration::Syncer::RSync::Pull
    rsync.superclass.should == Backup::Configuration::Syncer::RSync::Push
  end
end
