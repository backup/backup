# encoding: utf-8

require File.expand_path('../../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Syncer::RSync::Base do
  before do
    Backup::Configuration::Syncer::RSync::Base.defaults do |rsync|
      #rsync.directories         = 'cannot_have_a_default_value'
      rsync.path                = '~/backups/'
      rsync.mirror              = true
      rsync.additional_options  = []
    end
  end

  it 'should set the default rsync configuration' do
    rsync = Backup::Configuration::Syncer::RSync::Base
    rsync.path.should               == '~/backups/'
    rsync.mirror.should             == true
    rsync.additional_options.should == []
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Syncer::RSync::Base.clear_defaults!

      rsync = Backup::Configuration::Syncer::RSync::Base
      rsync.path.should               == nil
      rsync.mirror.should             == nil
      rsync.additional_options.should == nil
    end
  end
end
