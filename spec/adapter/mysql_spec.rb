# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Adapter::MySQL do

  it 'should read the adapter details correctly' do
    adapter = Backup::Adapter::MySQL.new do |adapter|
      adapter.database    = 'mydatabase'
      adapter.user        = 'someuser'
      adapter.password    = 'secret'
      adapter.skip_tables = ['logs', 'profiles']
      adapter.only_tables = ['users', 'pirates']
      adapter.additional_options = ['--single-transaction', '--quick']
    end

    adapter.database.should    == 'mydatabase'
    adapter.user.should        == 'someuser'
    adapter.password.should    == 'secret'
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

end
