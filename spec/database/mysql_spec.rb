# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Database::MySQL do

  let(:db) do
    Backup::Database::MySQL.new do |db|
      db.name      = 'mydatabase'
      db.user      = 'someuser'
      db.password  = 'secret'
      db.host      = 'localhost'
      db.port      = '123'
      db.socket    = '/mysql.sock'

      db.skip_tables = ['logs', 'profiles']
      db.only_tables = ['users', 'pirates']
      db.additional_options = ['--single-transaction', '--quick']
    end
  end

  it 'should read the adapter details correctly' do
    db.name.should      == 'mydatabase'
    db.user.should      == 'someuser'
    db.password.should  == 'secret'
    db.host.should      == 'localhost'
    db.port.should      == '123'
    db.socket.should    == '/mysql.sock'

    db.skip_tables.should == ['logs', 'profiles']
    db.only_tables.should == ['users', 'pirates']
    db.additional_options.should == ['--single-transaction', '--quick']
  end

  it 'arrays should default to empty arrays when not specified' do
    db = Backup::Database::MySQL.new do |db|
      db.name     = 'mydatabase'
      db.user     = 'someuser'
      db.password = 'secret'
    end

    db.skip_tables.should == []
    db.only_tables.should == []
    db.additional_options.should == []
  end

  describe '#skip_tables' do
    it 'should return a string for the mysqldump --ignore-tables option' do
      db.tables_to_skip.should == "--ignore-table='mydatabase.logs'\s--ignore-table='mydatabase.profiles'"
    end

    it 'should return an empty string' do
      db = Backup::Database::MySQL.new {}
      db.tables_to_skip.should == ""
    end
  end

  describe '#only_tables' do
    it 'should return a string for the mysqldump selected table to dump option' do
      db.tables_to_dump.should == "users\spirates"
    end

    it 'should return an empty string' do
      db = Backup::Database::MySQL.new {}
      db.tables_to_dump.should == ""
    end
  end

  describe '#credential_options' do
    it 'should return the mysql syntax for the credential options' do
      db.credential_options.should == "--user='someuser' --password='secret'"
    end

    it 'should only return the mysql syntax for the user' do
      db = Backup::Database::MySQL.new do |db|
        db.user = 'someuser'
      end

      db.credential_options.should == "--user='someuser'"
    end
  end

  describe '#connectivity_options' do
    it 'should return the mysql syntax for the connectivity options' do
      db.connectivity_options.should == "--host='localhost' --port='123' --socket='/mysql.sock'"
    end

    it 'should return only the socket' do
      db = Backup::Database::MySQL.new do |db|
        db.host   = ''
        db.port   = nil
        db.socket = '/mysql.sock'
      end

      db.connectivity_options.should == "--socket='/mysql.sock'"
    end
  end

  describe '#additional_options' do
    it 'should return a string of additional options specified by the user' do
      db.options.should == '--single-transaction --quick'
    end

    it 'should return an empty string' do
      db = Backup::Database::MySQL.new {}
      db.options.should == ""
    end
  end

  describe '#mysqldump_string' do
    it 'should return the full mysqldump string' do
      db.expects(:mysqldump_utility).returns('mysqldump')
      db.mysqldump.should ==
      "mysqldump --user='someuser' --password='secret' " +
      "--host='localhost' --port='123' --socket='/mysql.sock' " +
      "--single-transaction --quick mydatabase users pirates " +
      "--ignore-table='mydatabase.logs' --ignore-table='mydatabase.profiles'"
    end
  end

  describe '#perform!' do
    before do
      db.stubs(:mysqldump_utility).returns('mysqldump')
    end

    it 'should run the mysqldump command and dump it to the specified path' do
      db.stubs(:mkdir)
      db.expects(:run).with("#{db.mysqldump} > '#{TMP_PATH}/myapp/mysql/mydatabase.sql'")
      db.perform!
    end

    it 'should ensure the directory is available' do
      db.stubs(:run)
      db.expects(:mkdir).with("#{TMP_PATH}/myapp/mysql")
      db.perform!
    end
  end
end
