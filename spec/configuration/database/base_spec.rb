# encoding: utf-8

require File.expand_path('../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Database::Base do
  before do
    Backup::Configuration::Database::Base.defaults do |db|
      db.utility_path = '/usr/bin/my_util' # deprecated
    end
  end

  it 'should set the default Base configuration' do
    db = Backup::Configuration::Database::Base
    db.utility_path.should == '/usr/bin/my_util'
  end
end
