# encoding: utf-8

require File.dirname(__FILE__) + '/spec_helper'

class TestBackupCLI
  include Backup::CLI
end

describe Backup::CLI do
  let(:utility){ TestBackupCLI.new }
  describe '#run' do    
    it 'should return the value of the command' do
      utility.run('ls -lah').should_not be_nil
      #there should be a fair amount of stuff in there
      utility.run('ls -lah').size.should > 100 
    end

    it 'should be wrapped in a nice command' do
      utility.expects(:`).with('nice -n 20 ls -lah')
      utility.run('ls -lah')
    end
    
    it 'should strip out leading and trailing white space' do
      utility.expects(:`).with('nice -n 20 ls -lah')
      utility.run('    ls -lah ')
    end
    
    it 'should raise an exception if a command with no options cannot be found' do
      lambda{ utility.run('some_junk_command') }.should raise_exception(Backup::Exception::CommandNotFound)
    end

    it 'should raise an exception if a command with options cannot be found' do
      lambda{ utility.run('some_junk_command -cdl') }.should raise_exception(Backup::Exception::CommandNotFound)
    end
  end
  
  describe '#mkdir' do
    it 'should just be a wrapper' do
      path = "/some/path/here"
      FileUtils.expects(:mkdir_p).with(path)
      utility.mkdir(path)
    end
  end

  describe '#rm' do
    it 'should just be a wrapper' do
      path = "/some/path/here"
      FileUtils.expects(:rm_rf).with(path)
      utility.rm(path)
    end
  end

  
end
