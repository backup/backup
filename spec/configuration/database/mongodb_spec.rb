# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Database::MongoDB do
  before do
    Backup::Configuration::Database::MongoDB.defaults do |db|
      db.name               = 'mydb'
      db.username           = 'myuser'
      db.password           = 'mypassword'
      db.host               = 'myhost'
      db.port               = 'myport'
      db.only_collections   = %w[my other tables]
      db.additional_options = %w[my options]
      db.ipv6               = true
      db.mongodump_utility  = '/path/to/mongodump'
      db.mongo_utility      = '/path/to/mongo'
      db.lock               = true
    end
  end

  it 'should set the default MongoDB configuration' do
    db = Backup::Configuration::Database::MongoDB
    db.name.should                == 'mydb'
    db.username.should            == 'myuser'
    db.password.should            == 'mypassword'
    db.host.should                == 'myhost'
    db.port.should                == 'myport'
    db.only_collections.should    == %w[my other tables]
    db.additional_options.should  == %w[my options]
    db.ipv6.should                == true
    db.mongodump_utility.should   == '/path/to/mongodump'
    db.mongo_utility.should       == '/path/to/mongo'
    db.lock.should                == true
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Database::MongoDB.clear_defaults!

      db = Backup::Configuration::Database::MongoDB
      db.name.should                == nil
      db.username.should            == nil
      db.password.should            == nil
      db.host.should                == nil
      db.port.should                == nil
      db.only_collections.should    == nil
      db.additional_options.should  == nil
      db.ipv6.should                == nil
      db.mongodump_utility.should   == nil
      db.mongo_utility.should       == nil
      db.lock.should                == nil
    end
  end
end
