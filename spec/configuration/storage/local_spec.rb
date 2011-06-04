# encoding: utf-8

require File.dirname(__FILE__) + '/../../spec_helper'

describe Backup::Configuration::Storage::Local do
  before do
    Backup::Configuration::Storage::Local.defaults do |local|
      local.path = 'my_backups'
      local.keep = 20
    end
  end

  it 'should set the default local configuration' do
    local = Backup::Configuration::Storage::Local
    local.path.should == 'my_backups'
    local.keep.should == 20
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Storage::Local.clear_defaults!

      local = Backup::Configuration::Storage::Local
      local.path.should == nil
      local.keep.should == nil
    end
  end
end
