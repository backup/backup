# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

describe 'Backup::Configuration' do

  after do
    Backup::Configuration.send(:remove_const, 'Foo')
  end

  it 'should create modules for missing constants' do
    Backup::Configuration::Foo.class.should == Module
  end

  describe 'a generated module' do

    before do
      module Backup
        class Foo; end
      end
    end

    after do
      Backup.send(:remove_const, 'Foo')
    end

    it 'should create modules for missing constants' do
      Backup::Configuration::Foo::A::B.class.should == Module
    end

    it 'should pass calls to .defaults to the proper class' do
      Backup::Logger.expects(:warn)
      Backup::Foo.expects(:defaults)
      Backup::Configuration::Foo.defaults
    end

    it 'should pass a given block to .defaults to the proper class' do
      Backup::Logger.expects(:warn)
      configuration = mock
      Backup::Foo.expects(:defaults).yields(configuration)
      configuration.expects(:foo=).with('bar')

      Backup::Configuration::Foo.defaults do |config|
        config.foo = 'bar'
      end
    end

    it 'should log a deprecation warning' do
      Backup::Foo.stubs(:defaults)
      Backup::Logger.expects(:warn).with do |err|
        err.message.should ==
        "Configuration::Error: [DEPRECATION WARNING]\n" +
        "  Backup::Configuration::Foo.defaults is being deprecated.\n" +
        "  To set pre-configured defaults for Backup::Foo, use:\n" +
        "  Backup::Foo.defaults"
      end
      Backup::Configuration::Foo.defaults
    end

  end

end
