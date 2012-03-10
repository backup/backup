# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe 'Backup::Configuration::Store' do
  let(:store) { Backup::Configuration::Store.new }

  before do
    store.foo = 'one'
    store.bar = 'two'
  end

  it 'should be a subclass of OpenStruct' do
    Backup::Configuration::Store.superclass.should == OpenStruct
  end

  it 'should return nil for unset attributes' do
    store.foobar.should be_nil
  end

  describe '#_attribues' do
    it 'should return an array of attribute names' do
      store._attributes.should be_an Array
      store._attributes.count.should be(2)
      store._attributes.should include(:foo, :bar)
    end
  end

  describe '#reset!' do
    it 'should clear all attributes set' do
      store.reset!
      store._attributes.should be_an Array
      store._attributes.should be_empty
      store.foo.should be_nil
      store.bar.should be_nil
    end
  end

end
