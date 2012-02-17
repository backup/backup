# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Database::OpenLDAP do
  before do
    Backup::Configuration::Database::OpenLDAP.defaults do |db|
      db.name                = 'mydb'
      db.additional_options  = %w[my options]
      db.slapcat_utility     = '/path/to/slapcat'
    end
  end
  after { Backup::Configuration::Database::OpenLDAP.clear_defaults! }

  it 'should set the default OpenLDAP configuration' do
    db = Backup::Configuration::Database::OpenLDAP
    db.name.should                == 'mydb'
    db.additional_options.should  == %w[my options]
    db.slapcat_utility.should     == '/path/to/slapcat'
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Database::OpenLDAP.clear_defaults!

      db = Backup::Configuration::Database::OpenLDAP
      db.name.should                == nil
      db.additional_options.should  == nil
      db.slapcat_utility.should     == nil
    end
  end
end
