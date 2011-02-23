# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

class Backup::Configuration::HelpersTest
  extend Backup::Configuration::Helpers

  class << self
    attr_accessor :rspec_method, :rspec_test, :rspec_mocha
  end
end

describe Backup::Configuration::Helpers do
  it 'should clear the defaults' do
    Backup::Configuration::HelpersTest.expects(:send).with('rspec_method=', nil)
    Backup::Configuration::HelpersTest.expects(:send).with('rspec_test=', nil)
    Backup::Configuration::HelpersTest.expects(:send).with('rspec_mocha=', nil)
    Backup::Configuration::HelpersTest.clear_defaults!
  end

  it 'should return the setters' do
    Backup::Configuration::HelpersTest.setter_methods.count.should == 3
    %w[rspec_method= rspec_test= rspec_mocha=].each do |method|
      Backup::Configuration::HelpersTest.setter_methods.should include(method)
    end
  end

  it 'should return the getters' do
    Backup::Configuration::HelpersTest.getter_methods.count.should == 3
    %w[rspec_method rspec_test rspec_mocha].each do |method|
      Backup::Configuration::HelpersTest.getter_methods.should include(method)
    end
  end
end
