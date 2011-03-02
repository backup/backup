# encoding: utf-8

require File.dirname(__FILE__) + '/../../spec_helper'

describe Backup::Configuration::Database::Base do
  before do
    Backup::Configuration::Database::Base.defaults do |db|
      db.utility_path = '/usr/bin/my_util'
    end
  end

  it 'should set the default Base configuration' do
    db = Backup::Configuration::Database::Base
    db.utility_path.should == '/usr/bin/my_util'
  end
end
