# encoding: utf-8

require File.expand_path('../../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Syncer::SCM::Git do
  it 'should be a subclass of SCM::Base' do
    git = Backup::Configuration::Syncer::SCM::Git
    git.superclass.should == Backup::Configuration::Syncer::SCM::Base
  end
end
