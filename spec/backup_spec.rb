# encoding: utf-8

require File.dirname(__FILE__) + '/spec_helper'

describe Backup do
  it do
    Backup::TMP_PATH.should    == File.join(ENV['HOME'], 'Backup', '.tmp')
    Backup::DATA_PATH.should   == File.join(ENV['HOME'], 'Backup', 'data')
    Backup::CONFIG_FILE.should == File.join(ENV['HOME'], 'Backup', 'config.rb')
  end
end
