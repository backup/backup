# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

describe Backup::CLI::Helpers do
  let(:helpers) { Module.new.extend(subject) }

  describe '#raise_if_command_failed!' do

    it 'returns nil if status exit code is in ignore_exit_codes' do
      process_data = { :status => '3', :ignore_exit_codes => [1,3,5] }
      helpers.raise_if_command_failed!('foo', process_data).should be_nil
    end

    it 'raises an error with stdout/stderr data' do
      process_data = { :status => '3', :ignore_exit_codes => [2,4,6],
                       :stdout => 'stdout data', :stderr => 'stderr data' }

      expect do
        helpers.raise_if_command_failed!('utility_name', process_data)
      end.to raise_error(
        Backup::Errors::CLI::SystemCallError,
        "CLI::SystemCallError: Failed to run utility_name on #{RUBY_PLATFORM}\n" +
        "  The following information should help to determine the problem:\n" +
        "  Exit Code: 3\n" +
        "  STDERR:\n" +
        "  stderr data\n" +
        "  STDOUT:\n" +
        "  stdout data"
      )
    end

  end

end
