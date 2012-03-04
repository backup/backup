# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Syncer::Base do
  before do
    Backup::Configuration::Syncer::Base.defaults do |rsync|
      rsync.path                = '~/backups/'
      rsync.mirror              = true
      #rsync.directories         = 'cannot_have_a_default_value'
    end
  end
  after { Backup::Configuration::Syncer::Base.clear_defaults! }

  it 'should set the default syncer configuration' do
    rsync = Backup::Configuration::Syncer::Base
    rsync.path.should               == '~/backups/'
    rsync.mirror.should             == true
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Syncer::Base.clear_defaults!

      rsync = Backup::Configuration::Syncer::Base
      rsync.path.should               == nil
      rsync.mirror.should             == nil
    end
  end
end
