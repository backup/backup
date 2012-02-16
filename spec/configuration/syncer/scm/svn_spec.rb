# encoding: utf-8

require File.expand_path('../../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Syncer::SCM::SVN do
  it 'should be a subclass of SCM::Base' do
    svn = Backup::Configuration::Syncer::SCM::SVN
    svn.superclass.should == Backup::Configuration::Syncer::SCM::Base
  end
end
