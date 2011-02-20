# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

class Backup::Configuration::Base
  class << self
    attr_accessor :rspec_method, :rspec_test, :rspec_mocha
  end
end

describe Backup::Configuration::Base do
  it 'should clear the defaults' do
    Backup::Configuration::Base.expects(:send).with('rspec_method=', nil)
    Backup::Configuration::Base.expects(:send).with('rspec_test=', nil)
    Backup::Configuration::Base.expects(:send).with('rspec_mocha=', nil)
    Backup::Configuration::Base.clear_defaults!
  end
end
