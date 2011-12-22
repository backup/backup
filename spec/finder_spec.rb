# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

describe Backup::Finder do

  describe '#find' do
    let(:finder) { Backup::Finder.new('test_trigger', 'foo') }

    before do
      finder.stubs(:load_config!)
    end

    it 'should return the first model that matches the trigger' do
      models = %w{ foo1 test_trigger foo2 test_trigger }.map do |trigger|
        stub(:trigger => trigger.to_sym)
      end
      Backup::Model.expects(:all).returns(models)
      Backup::Model.expects(:current=).with(models[1])

      expect do
        finder.find.should == models[1]
      end.not_to raise_error
    end

    it 'should raise an error when no models match the trigger' do
      models = %w{ foo1 foo2 foo3 }.map do |trigger|
        stub(:trigger => trigger.to_sym)
      end
      Backup::Model.expects(:all).returns(models)
      Backup::Model.expects(:current=).never

      expect do
        finder.find
      end.to raise_error(
        Backup::Errors::Finder::MissingTriggerError,
        "Finder::MissingTriggerError: Could not find trigger 'test_trigger' in 'foo'."
      )
    end

  end # describe '#find'

  describe '#load_config!' do
    let(:finder) { Backup::Finder.new('foo', 'config_file') }

    context 'when given a valid config file' do

      before do
        File.expects(:exist?).with('config_file').returns(true)
      end

      it 'should load the config file' do
        File.expects(:read).with('config_file').returns(:file_contents)
        Backup.expects(:module_eval).with(:file_contents, 'config_file', 1)

        finder.send(:load_config!)
      end

      it 'should reset Model.all' do
        File.stubs(:read)
        Backup.stubs(:module_eval)
        Backup::Model.expects(:all=).with([])

        finder.send(:load_config!)
      end

    end # context 'when given a valid config file'

    context 'when given a config file that does not exist' do

      before do
        File.expects(:exist?).with('config_file').returns(false)
      end

      it 'should raise an error' do
        Backup::Model.expects(:all=).never
        File.expects(:read).never
        Backup.expects(:module_eval).never

        expect do
          finder.send(:load_config!)
        end.to raise_error(
          Backup::Errors::Finder::MissingConfigError,
          "Finder::MissingConfigError: Could not find configuration file: 'config_file'."
        )
      end

    end # context 'when given a config file that does not exist'

  end # describe '#find'
end
