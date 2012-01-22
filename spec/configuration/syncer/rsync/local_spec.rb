# encoding: utf-8

require File.expand_path('../../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Syncer::RSync::Local do
  it 'should be a subclass of RSync::Base' do
    rsync = Backup::Configuration::Syncer::RSync::Local
    rsync.superclass.should == Backup::Configuration::Syncer::RSync::Base
  end
end
