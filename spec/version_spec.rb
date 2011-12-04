# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

def set_version(major, minor, patch)
  Backup::Version.stubs(:major).returns(major)
  Backup::Version.stubs(:minor).returns(minor)
  Backup::Version.stubs(:patch).returns(patch)
end

describe Backup::Version do
  it 'should return a nicer gemspec output' do
    set_version(1,2,3)
    Backup::Version.current.should == '1.2.3'
  end

  it 'should return a nicer gemspec output with build' do
    set_version(4,5,6)
    Backup::Version.current.should == '4.5.6'
  end
end
