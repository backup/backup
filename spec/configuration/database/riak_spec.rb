# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Database::Riak do
  before do
    Backup::Configuration::Database::Riak.defaults do |db|
      db.name   = 'mydb'
      db.node   = '/var/lib/redis/db'
      db.cookie = 'mypassword'
    end
  end

  it 'should set the default Riak configuration' do
    db = Backup::Configuration::Database::Riak
    db.name.should   == 'mydb'
    db.node.should   == '/var/lib/redis/db'
    db.cookie.should == 'mypassword'
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Database::Riak.clear_defaults!

      db = Backup::Configuration::Database::Riak
      db.name.should   == nil
      db.node.should   == nil
      db.cookie.should == nil
    end
  end
end
