# encoding: utf-8

require File.expand_path('../../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Syncer::RSync::Local do
  before do
    Backup::Configuration::Syncer::RSync::Local.defaults do |rsync|
      rsync.path      = '~/backups/'
      rsync.mirror    = true
      rsync.additional_options = []
    end
  end

  it 'should set the default rsync configuration' do
    rsync = Backup::Configuration::Syncer::RSync::Local
    rsync.path.should      == '~/backups/'
    rsync.mirror.should    == true
    rsync.additional_options.should == []
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Syncer::RSync::Local.clear_defaults!

      rsync = Backup::Configuration::Syncer::RSync::Local
      rsync.path.should      == nil
      rsync.mirror.should    == nil
      rsync.additional_options.should == nil
    end
  end
end
