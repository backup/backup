# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Database::PostgreSQL do

  before do
    Backup::Database::PostgreSQL.any_instance.stubs(:load_defaults!)
  end

  let(:db) do
    Backup::Database::PostgreSQL.new do |db|
      db.name      = 'mydatabase'
      db.username  = 'someuser'
      db.password  = 'secret'
      db.host      = 'localhost'
      db.port      = '123'
      db.socket    = '/pg.sock'

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
      db.socket.should    == '/pg.sock'

      db.skip_tables.should == ['logs', 'profiles']
      db.only_tables.should == ['users', 'pirates']
      db.additional_options.should == ['--single-transaction', '--quick']
    end

    it 'arrays should default to empty arrays when not specified' do
      db = Backup::Database::PostgreSQL.new do |db|
        db.name     = 'mydatabase'
        db.username = 'someuser'
        db.password = 'secret'
      end

      db.skip_tables.should == []
      db.only_tables.should == []
      db.additional_options.should == []
    end

    it 'handles an empty username' do
      db = Backup::Database::PostgreSQL.new {}
      db.username = ''

      db.username_options.should == ''
      db.password_options.should == ''
    end

    it 'handles a nil username' do
      db = Backup::Database::PostgreSQL.new {}
      db.username = nil

      db.username_options.should == ''
      db.password_options.should == ''
    end
  end

  describe '#skip_tables' do
    it 'should return a string for the pg_dump --ignore-tables option' do
      db.tables_to_skip.should == "--exclude-table='logs' --exclude-table='profiles'"
    end

    it 'should return an empty string' do
      db = Backup::Database::PostgreSQL.new {}
      db.tables_to_skip.should == ""
    end
  end

  describe '#only_tables' do
    it 'should return a string for the pg_dump selected table to dump option' do
      db.tables_to_dump.should == "--table='users' --table='pirates'"
    end

    it 'should return an empty string' do
      db = Backup::Database::PostgreSQL.new {}
      db.tables_to_dump.should == ""
    end
  end

  describe '#username_options' do
    it 'should return the postgresql syntax for the username options' do
      db.username_options.should == "--username='someuser'"
    end

    it 'should only return the postgresql syntax for the user' do
      db = Backup::Database::PostgreSQL.new do |db|
        db.username = 'someuser'
      end

      db.username_options.should == "--username='someuser'"
    end
  end

  describe '#password_options' do
    it 'returns the environment variable set for the password' do
      db.password_options.should == "PGPASSWORD='secret'"
    end
  end

  describe '#connectivity_options' do
    it 'should return the postgresql syntax for the connectivity options' do
      db.connectivity_options.should == "--host='localhost' --port='123' --host='/pg.sock'"
    end

    it 'should return only the socket' do
      db = Backup::Database::PostgreSQL.new do |db|
        db.host   = ''
        db.port   = nil
        db.socket = '/pg.sock'
      end

      db.connectivity_options.should == "--host='/pg.sock'"
    end
  end

  describe '#additional_options' do
    it 'should return a string of additional options specified by the user' do
      db.options.should == '--single-transaction --quick'
    end

    it 'should return an empty string' do
      db = Backup::Database::PostgreSQL.new {}
      db.options.should == ""
    end
  end

  describe '#pg_dump_string' do
    before do
      db.expects(:utility).with(:pg_dump).returns('pg_dump')
    end

    it 'should return the full pg_dump string' do
      db.pgdump.should ==
      "PGPASSWORD='secret' pg_dump --username='someuser' " +
      "--host='localhost' --port='123' --host='/pg.sock' " +
      "--single-transaction --quick --table='users' --table='pirates' " +
      "--exclude-table='logs' --exclude-table='profiles' mydatabase"
    end

    it 'returns the full pg_dump string when a password is not specified' do
      db.password = nil
      db.pgdump.should ==
          "pg_dump --username='someuser' " +
          "--host='localhost' --port='123' --host='/pg.sock' " +
          "--single-transaction --quick --table='users' --table='pirates' " +
          "--exclude-table='logs' --exclude-table='profiles' mydatabase"

    end
  end

  describe '#perform!' do
    before do
      db.stubs(:utility).returns('pg_dump')
      db.stubs(:mkdir)
      db.stubs(:run)
    end

    it 'should ensure the directory is available' do
      db.expects(:mkdir).with(File.join(Backup::TMP_PATH, "myapp", "PostgreSQL"))
      db.perform!
    end

    it 'should run the pg_dump command and dump it to the specified path' do
      db.expects(:run).with("#{db.pgdump} > '#{Backup::TMP_PATH}/myapp/PostgreSQL/mydatabase.sql'")
      db.perform!
    end

    it do
      Backup::Logger.expects(:message).with("Backup::Database::PostgreSQL started dumping and archiving \"mydatabase\".")
      db.perform!
    end
  end
end
