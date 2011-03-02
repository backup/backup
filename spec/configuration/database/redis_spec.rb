# encoding: utf-8

require File.dirname(__FILE__) + '/../../spec_helper'

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
    end
  end

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
  end
end
