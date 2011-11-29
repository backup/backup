# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Database::Riak do

  before do
    Backup::Database::Riak.any_instance.stubs(:load_defaults!)
  end

  let(:db) do
    Backup::Database::Riak.new do |db|
      db.name      = 'mydatabase'
      db.node      = 'riak@localhost'
      db.cookie    = 'riak'
    end
  end

  describe '#new' do
    it 'should read the adapter details correctly' do
      db.name.should      == 'mydatabase'
      db.node.should      == 'riak@localhost'
      db.cookie.should    == 'riak'
    end
  end

  describe '#riakadmin_string' do
    it 'should return the full riakadmin string' do
      db.riakadmin.should == "riak-admin backup riak@localhost riak"
    end
  end

  describe '#perform!' do
    before do
      db.stubs(:mkdir)
      db.stubs(:run)
    end

    it 'should ensure the directory is available' do
      db.expects(:mkdir).with(File.join(Backup::TMP_PATH, "myapp", "Riak"))
      db.perform!
    end

    it do
      Backup::Logger.expects(:message).with("Backup::Database::Riak started dumping and archiving \"mydatabase\".")
      db.perform!
    end
  end
end