# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::Compressor::Custom do
  let(:compressor) { Backup::Compressor::Custom.new }

  before(:all) do
    # Utilities::Helpers#utility will raise an error
    # if the command is invalid or not set
    Backup::Compressor::Custom.send(
      :define_method, :utility,
      lambda {|arg| arg.to_s.empty? ? 'error' : "/path/to/#{ arg }" }
    )
  end

  it 'should be a subclass of Compressor::Base' do
    Backup::Compressor::Custom.
      superclass.should == Backup::Compressor::Base
  end

  describe '#initialize' do
    let(:compressor) { Backup::Compressor::Custom.new }

    after { Backup::Compressor::Custom.clear_defaults! }

    it 'should load pre-configured defaults' do
      Backup::Compressor::Custom.any_instance.expects(:load_defaults!)
      compressor
    end

    it 'should call Utilities::Helpers#utility to validate command' do
      Backup::Compressor::Custom.any_instance.expects(:utility)
      compressor
    end

    it 'should clean the command and extension for use with compress_with' do
      compressor = Backup::Compressor::Custom.new do |c|
        c.command   = ' my_command --option foo '
        c.extension = ' my_extension '
      end

      compressor.command.should   == ' my_command --option foo '
      compressor.extension.should == ' my_extension '

      compressor.expects(:log!)
      compressor.compress_with do |cmd, ext|
        cmd.should == '/path/to/my_command --option foo'
        ext.should == 'my_extension'
      end
    end

    context 'when no pre-configured defaults have been set' do
      it 'should use default values' do
        compressor.command.should   be_nil
        compressor.extension.should be_nil

        compressor.instance_variable_get(:@cmd).should == 'error'
        compressor.instance_variable_get(:@ext).should == ''
      end

      it 'should use the values given' do
        compressor = Backup::Compressor::Custom.new do |c|
          c.command   = 'my_command'
          c.extension = 'my_extension'
        end

        compressor.command.should   == 'my_command'
        compressor.extension.should == 'my_extension'

        compressor.instance_variable_get(:@cmd).should == '/path/to/my_command'
        compressor.instance_variable_get(:@ext).should == 'my_extension'
      end
    end # context 'when no pre-configured defaults have been set'

    context 'when pre-configured defaults have been set' do
      before do
        Backup::Compressor::Custom.defaults do |c|
          c.command   = 'default_command'
          c.extension = 'default_extension'
        end
      end

      it 'should use pre-configured defaults' do
        compressor.command.should   == 'default_command'
        compressor.extension.should == 'default_extension'

        compressor.instance_variable_get(:@cmd).should == '/path/to/default_command'
        compressor.instance_variable_get(:@ext).should == 'default_extension'
      end

      it 'should override pre-configured defaults' do
        compressor = Backup::Compressor::Custom.new do |c|
          c.command   = 'new_command'
          c.extension = 'new_extension'
        end

        compressor.command.should   == 'new_command'
        compressor.extension.should == 'new_extension'

        compressor.instance_variable_get(:@cmd).should == '/path/to/new_command'
        compressor.instance_variable_get(:@ext).should == 'new_extension'
      end
    end # context 'when pre-configured defaults have been set'
  end # describe '#initialize'
end
