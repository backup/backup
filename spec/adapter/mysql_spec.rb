# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Adapter::MySQL do

  let(:adapter) do
    Backup::Adapter::MySQL.new do |adapter|
      adapter.database    = 'mydatabase'
      adapter.user        = 'someuser'
      adapter.password    = 'secret'
      adapter.host        = 'localhost'
      adapter.port        = '123'
      adapter.socket      = '/mysql.sock'

      adapter.skip_tables = ['logs', 'profiles']
      adapter.only_tables = ['users', 'pirates']
      adapter.additional_options = ['--single-transaction', '--quick']
    end
  end

  it 'should read the adapter details correctly' do
    adapter.database.should    == 'mydatabase'
    adapter.user.should        == 'someuser'
    adapter.password.should    == 'secret'
    adapter.host.should        == 'localhost'
    adapter.port.should        == '123'
    adapter.socket.should      == '/mysql.sock'

    adapter.skip_tables.should == ['logs', 'profiles']
    adapter.only_tables.should == ['users', 'pirates']
    adapter.additional_options.should == ['--single-transaction', '--quick']
  end

  it 'arrays should default to empty arrays when not specified' do
    adapter = Backup::Adapter::MySQL.new do |adapter|
      adapter.database    = 'mydatabase'
      adapter.user        = 'someuser'
      adapter.password    = 'secret'
    end

    adapter.skip_tables.should == []
    adapter.only_tables.should == []
    adapter.additional_options.should == []
  end

  describe '#skip_tables' do
    it 'should return a string for the mysqldump --ignore-tables option' do
      adapter.tables_to_skip.should == "--ignore-table='mydatabase.logs'\s--ignore-table='mydatabase.profiles'"
    end

    it 'should return an empty string' do
      adapter = Backup::Adapter::MySQL.new {}
      adapter.tables_to_skip.should == ""
    end
  end

  describe '#only_tables' do
    it 'should return a string for the mysqldump selected table to dump option' do
      adapter.tables_to_dump.should == "users\spirates"
    end

    it 'should return an empty string' do
      adapter = Backup::Adapter::MySQL.new {}
      adapter.tables_to_dump.should == ""
    end
  end

  describe '#credential_options' do
    it 'should return the mysql syntax for the credential options' do
      adapter.credential_options.should == "--user='someuser' --password='secret'"
    end

    it 'should only return the mysql syntax for the user' do
      adapter = Backup::Adapter::MySQL.new do |adapter|
        adapter.user = 'someuser'
      end

      adapter.credential_options.should == "--user='someuser'"
    end
  end

  describe '#connectivity_options' do
    it 'should return the mysql syntax for the connectivity options' do
      adapter.connectivity_options.should == "--host='localhost' --port='123' --socket='/mysql.sock'"
    end

    it 'should return only the socket' do
      adapter = Backup::Adapter::MySQL.new do |adapter|
        adapter.host   = ''
        adapter.port   = nil
        adapter.socket = '/mysql.sock'
      end

      adapter.connectivity_options.should == "--socket='/mysql.sock'"
    end
  end

  describe '#additional_options' do
    it 'should return a string of additional options specified by the user' do
      adapter.options.should == '--single-transaction --quick'
    end

    it 'should return an empty string' do
      adapter = Backup::Adapter::MySQL.new {}
      adapter.options.should == ""
    end
  end

  describe '#mysqldump_string' do
    it 'should return the full mysqldump string' do
      adapter.expects(:mysqldump_utility).returns('mysqldump')
      adapter.mysqldump.should ==
      "mysqldump --user='someuser' --password='secret' " +
      "--host='localhost' --port='123' --socket='/mysql.sock' " +
      "--single-transaction --quick mydatabase users pirates " +
      "--ignore-table='mydatabase.logs' --ignore-table='mydatabase.profiles'"
    end
  end

  describe '#perform' do
    it 'should run the mysqldump command and dump it to the specified path' do
      adapter.stubs(:mkdir)
      adapter.expects(:run).with("#{adapter.mysqldump} > '/Users/Michael/tmp/backup/myapp/mysql/mydatabase.sql'")
      adapter.perform('/Users/Michael/tmp/backup/myapp')
    end

    it 'should ensure the directory is available' do
      adapter.stubs(:run)
      adapter.expects(:mkdir).with('/Users/Michael/tmp/backup/myapp/mysql')
      adapter.perform('/Users/Michael/tmp/backup/myapp')
    end
  end
end
