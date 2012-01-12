# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Database::Redis do
  before do
    Backup::Configuration::Database::Redis.defaults do |db|
      db.name                = 'mydb'
      db.path                = '/var/lib/redis/db'
      db.password            = 'mypassword'
      db.invoke_save         = true
      db.host                = 'localhost'
      db.port                = 123
      db.socket              = '/redis.sock'
      db.additional_options  = %w[my options]
      db.redis_cli_utility   = '/path/to/redis-cli'
    end
  end
  after { Backup::Configuration::Database::Redis.clear_defaults! }

  it 'should set the default Redis configuration' do
    db = Backup::Configuration::Database::Redis
    db.name.should                == 'mydb'
    db.path.should                == '/var/lib/redis/db'
    db.password.should            == 'mypassword'
    db.invoke_save.should         == true
    db.host.should                == 'localhost'
    db.port.should                == 123
    db.socket.should              == '/redis.sock'
    db.additional_options.should  == %w[my options]
    db.redis_cli_utility.should   == '/path/to/redis-cli'
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Database::Redis.clear_defaults!

      db = Backup::Configuration::Database::Redis
      db.name.should                == nil
      db.path.should                == nil
      db.password.should            == nil
      db.invoke_save.should         == nil
      db.host.should                == nil
      db.port.should                == nil
      db.socket.should              == nil
      db.additional_options.should  == nil
      db.redis_cli_utility.should   == nil
    end
  end
end
