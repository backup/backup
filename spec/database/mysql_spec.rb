# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Database::MySQL do

  before do
    Backup::Database::MySQL.any_instance.stubs(:load_defaults!)
  end

  let(:db) do
    Backup::Database::MySQL.new do |db|
      db.name      = 'mydatabase'
      db.username  = 'someuser'
      db.password  = 'secret'
      db.host      = 'localhost'
      db.port      = '123'
      db.socket    = '/mysql.sock'

      db.skip_tables = ['logs', 'profiles']
      db.only_tables = ['users', 'pirates']
      db.additional_options = ['--single-transaction', '--quick']
    end
  end

  describe '#new' do
    it 'should read the adapter details correctly' do
      db.name.should      == 'mydatabase'
      db.username.should  == 'someuser'
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
        db.username = 'someuser'
        db.password = 'secret'
      end

      db.skip_tables.should == []
      db.only_tables.should == []
      db.additional_options.should == []
    end
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
        db.username = 'someuser'
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
      db.expects(:utility).with(:mysqldump).returns('mysqldump')
      db.mysqldump.should ==
      "mysqldump --user='someuser' --password='secret' " +
      "--host='localhost' --port='123' --socket='/mysql.sock' " +
      "--single-transaction --quick mydatabase users pirates " +
      "--ignore-table='mydatabase.logs' --ignore-table='mydatabase.profiles'"
    end
  end

  describe '#perform!' do
    before do
      db.stubs(:utility).returns('mysqldump')
      db.stubs(:mkdir)
      db.stubs(:run)
    end

    it 'should ensure the directory is available' do
      db.expects(:mkdir).with(File.join(Backup::TMP_PATH, "myapp", "MySQL"))
      db.perform!
    end

    it 'should run the mysqldump command and dump it to the specified path' do
      db.expects(:run).with("#{db.mysqldump} > '#{Backup::TMP_PATH}/myapp/MySQL/mydatabase.sql'")
      db.perform!
    end

    it do
      Backup::Logger.expects(:message).
          with("Backup::Database::MySQL started dumping and archiving 'mydatabase'.")
      db.perform!
    end
  end
end
