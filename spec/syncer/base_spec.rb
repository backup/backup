# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Syncer::Base do
  let(:base)    { Backup::Syncer::Base }
  let(:syncer)  { base.new }

  it 'should include CLI::Helpers' do
    base.included_modules.should include(Backup::CLI::Helpers)
  end

  it 'should include Configuration::Helpers' do
    base.included_modules.should include(Backup::Configuration::Helpers)
  end

  describe '#syncer_name' do
    it 'should return the class name with the Backup:: namespace removed' do
      syncer.send(:syncer_name).should == 'Syncer::Base'
    end
  end
end
