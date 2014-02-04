# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Config::DSL do

  describe '.add_dsl_constants' do
    it 'adds constants when the module is loaded' do
      described_class.constants.each do |const|
        described_class.send(:remove_const, const)
      end
      described_class.constants.should be_empty

      load File.expand_path('../../../lib/backup/config/dsl.rb', __FILE__)

      expect( described_class.const_defined?('MySQL') ).to be_true
      expect( described_class.const_defined?('RSync') ).to be_true
      expect( described_class::RSync.const_defined?('Local') ).to be_true
    end
  end

  describe '.create_modules' do
    module TestScope; end

    context 'when given an array of constant names' do
      it 'creates modules for the given scope' do
        described_class.send(:create_modules, TestScope, ['Foo', 'Bar'])
        TestScope.const_defined?('Foo').should be_true
        TestScope.const_defined?('Bar').should be_true
        TestScope::Foo.class.should == Module
        TestScope::Bar.class.should == Module
      end
    end

    context 'when the given array contains Hash values' do
      it 'creates deeply nested modules' do
        described_class.send(
          :create_modules,
          TestScope,
          [ 'FooBar', {
            :LevelA => [ 'NameA', {
              :LevelB => ['NameB']
            } ]
          } ]
        )
        TestScope.const_defined?('FooBar').should be_true
        TestScope.const_defined?('LevelA').should be_true
        TestScope::LevelA.const_defined?('NameA').should be_true
        TestScope::LevelA.const_defined?('LevelB').should be_true
        TestScope::LevelA::LevelB.const_defined?('NameB').should be_true
      end
    end
  end

  describe '#_config_options' do
    it 'returns paths set in config.rb' do
      [:root_path, :data_path, :tmp_path].each {|name| subject.send(name, name) }
      expect( subject._config_options ).to eq(
        { :root_path => :root_path,
          :data_path => :data_path,
          :tmp_path  => :tmp_path }
      )
    end
  end

  describe '#preconfigure' do
    after do
      if described_class.const_defined?('MyBackup')
        described_class.send(:remove_const, 'MyBackup')
      end
    end

    specify 'name must be a String' do
      expect do
        subject.preconfigure(:Abc)
      end.to raise_error(described_class::Error)
    end

    specify 'name must begin with a capital letter' do
      expect do
        subject.preconfigure('myBackup')
      end.to raise_error(described_class::Error)
    end

    specify 'Backup::Model may not be preconfigured' do
      expect do
        subject.preconfigure('Model')
      end.to raise_error(described_class::Error)
    end

    specify 'preconfigured models can only be preconfigured once' do
      block = Proc.new {}
      subject.preconfigure('MyBackup', &block)
      klass = described_class.const_get('MyBackup')
      klass.superclass.should == Backup::Model

      expect do
        subject.preconfigure('MyBackup', &block)
      end.to raise_error(described_class::Error)
    end
  end

end
end
