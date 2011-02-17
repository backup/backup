# encoding: utf-8

require File.dirname(__FILE__) + '/spec_helper'

def set_version(major, minor, patch, build)
  Backup::Version.stubs(:major).returns(major)
  Backup::Version.stubs(:minor).returns(minor)
  Backup::Version.stubs(:patch).returns(patch)
  Backup::Version.stubs(:build).returns(build)
end

describe Backup::Version do
  it 'should return a valid gemspec version' do
    set_version(1,2,3,false)
    Backup::Version.gemspec.should == '1.2.3'
  end

  it 'should return a valid gemspec version with a build' do
    set_version(4,5,6,615)
    Backup::Version.gemspec.should == '4.5.6.build.615'
  end

  it 'should return a nicer gemspec output' do
    set_version(1,2,3,false)
    Backup::Version.current.should == '1.2.3 / build 0'
  end

  it 'should return a nicer gemspec output with build' do
    set_version(4,5,6,615)
    Backup::Version.current.should == '4.5.6 / build 615'
  end
end
