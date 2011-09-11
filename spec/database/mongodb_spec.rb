# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Database::MongoDB do

  before do
    Backup::Database::MongoDB.any_instance.stubs(:load_defaults!)
  end

  let(:db) do
    Backup::Database::MongoDB.new do |db|
      db.name      = 'mydatabase'
      db.username  = 'someuser'
      db.password  = 'secret'
      db.host      = 'localhost'
      db.port      = 123

      db.ipv6               = true
      db.only_collections   = ['users', 'pirates']
      db.additional_options = ['--query']
    end
  end

  describe '#new' do
    it 'should read the adapter details correctly' do
      db.name.should      == 'mydatabase'
      db.username.should  == 'someuser'
      db.password.should  == 'secret'
      db.host.should      == 'localhost'
      db.port.should      == 123

      db.only_collections.should == ['users', 'pirates']
      db.additional_options.should == '--query'
    end

    it 'arrays should default to empty arrays when not specified' do
      db = Backup::Database::MongoDB.new do |db|
        db.name     = 'mydatabase'
        db.username = 'someuser'
        db.password = 'secret'
      end

      db.only_collections.should   == []
      db.additional_options.should == ""
    end

    it 'should ensure the directory is available' do
      Backup::Database::MongoDB.any_instance.expects(:mkdir).with("#{Backup::TMP_PATH}/myapp/MongoDB")
      Backup::Database::MongoDB.new {}
    end
  end

  describe '#only_collections' do
    it 'should return a string for the mongodump selected table to dump option' do
      db.collections_to_dump.should == %w[users pirates]
    end
  end

  describe '#credential_options' do
    it 'should return the mongo syntax for the credential options' do
      db.credential_options.should == "--username='someuser' --password='secret'"
    end

    it 'should only return the mongo syntax for the user' do
      db = Backup::Database::MongoDB.new do |db|
        db.username = 'someuser'
      end

      db.credential_options.should == "--username='someuser'"
    end
  end

  describe '#connectivity_options' do
    it 'should return the mongo syntax for the connectivity options' do
      db.connectivity_options.should == "--host='localhost' --port='123'"
    end

    it 'should return only the socket' do
      db = Backup::Database::MongoDB.new do |db|
        db.host   = ''
        db.port   = 123
      end

      db.connectivity_options.should == "--port='123'"
    end
  end

  describe '#ipv6' do
    it 'should return a mongodb syntax compatible ipv6 flag' do
      db.ipv6 = true
      db.ipv6.should == '--ipv6'
    end

    it 'should return an empty string' do
      db.ipv6 = nil
      db.ipv6.should == ''
    end
  end

  describe '#mongodump_string' do
    it 'should return the full mongodump string' do
      db.expects(:utility).with(:mongodump).returns('mongodump')
      db.mongodump.should ==
      "mongodump --db='mydatabase' --username='someuser' --password='secret' " +
      "--host='localhost' --port='123' --ipv6 --query --out='#{ File.join(Backup::TMP_PATH, Backup::TRIGGER, 'MongoDB') }'"
    end
  end

  describe '#perform!' do
    before do
      db.stubs(:utility).returns('mongodump')
      db.stubs(:mkdir)
      db.stubs(:run)
    end

    it 'should run the mongodump command and dump all collections' do
      db.only_collections = []
      db.expects(:dump!)

      db.perform!
    end

    it 'should run the mongodump command and dump all collections' do
      db.only_collections = nil
      db.expects(:dump!)

      db.perform!
    end

    it 'should lock database before dump if lock mode is enabled' do
      db.lock = true
      db.expects(:lock_database)

      db.perform!
    end

    it 'should not lock database before dump if lock mode is disabled' do
      db.lock = false
      db.expects(:lock_database).never

      db.perform!
    end

    it 'should unlock database after dump if lock mode is enabled' do
      db.lock = true
      db.expects(:unlock_database)

      db.perform!
    end

    it 'should unlock the database if an exception is raised after it was locked' do
      db.lock = true
      db.expects(:unlock_database)
      db.expects(:lock_database).raises(RuntimeError, 'something went wrong')
      db.expects(:raise)

      db.perform!
    end

    it 'should not unlock database after dump if lock mode is disabled' do
      db.lock = false
      db.expects(:unlock_database).never

      db.perform!
    end

    it 'should dump only the provided collections' do
      db.only_collections = %w[users admins profiles]
      db.expects(:specific_collection_dump!)

      db.perform!
    end

    it do
      Backup::Logger.expects(:message).with("Backup::Database::MongoDB started dumping and archiving \"mydatabase\".")
      db.perform!
    end
  end
end
