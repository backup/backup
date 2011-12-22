# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

describe Backup do
  it do
    Backup::TMP_PATH.should    == File.join(ENV['HOME'], 'Backup', '.tmp')
    Backup::DATA_PATH.should   == File.join(ENV['HOME'], 'Backup', 'data')
    Backup::CONFIG_FILE.should == File.join(ENV['HOME'], 'Backup', 'config.rb')
  end
end
