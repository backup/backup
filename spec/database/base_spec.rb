# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Database::Base do

  before do
    class Backup::Database::Base
      def initialize(&block)
        instance_eval(&block) if block_given?
      end
    end
  end

  let(:db) do
    Backup::Database::Base.new do |db|
      db.utility_path = '/var/usr/my_util'
    end
  end

  it 'should return the utility path instead of auto-detecting it' do
    db.utility(:my_database_util).should == '/var/usr/my_util'
  end

  it 'should ignore the utility_path when not defined' do
    db = Backup::Database::Base.new
    db.utility(:my_database_util).should == :my_database_util
  end

  describe '#perform!' do
    it 'should invoke prepare! and log!' do
      db.expects(:prepare!)
      db.expects(:log!)

      db.perform!
    end
  end

end
