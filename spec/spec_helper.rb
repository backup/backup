# encoding: utf-8

require 'rubygems' if RUBY_VERSION < '1.9'
require 'bundler/setup'
require 'backup'

require 'timecop'

# ::FileUtils will always be either SandboxFileUtils or FileUtils::NoWrite.
require File.expand_path('../support/sandbox_file_utils.rb', __FILE__)
# SandboxFileUtils.deactivate!(:noop) will be called before each example,
# which will set ::FileUtils to FileUtils::NoWrite if SandboxFileUtils is active.
SandboxFileUtils.activate!

module Backup::ExampleHelpers
  # ripped from MiniTest :)
  # RSpec doesn't have a method for this? Am I missing something?
  def capture_io
    require 'stringio'

    orig_stdout, orig_stderr = $stdout, $stderr
    captured_stdout, captured_stderr = StringIO.new, StringIO.new
    $stdout, $stderr = captured_stdout, captured_stderr

    yield

    return captured_stdout.string, captured_stderr.string
  ensure
    $stdout = orig_stdout
    $stderr = orig_stderr
  end
end

require 'rspec/autorun'
RSpec.configure do |config|
  ##
  # Use Mocha to mock with RSpec
  config.mock_with :mocha

  ##
  # Example Helpers
  config.include Backup::ExampleHelpers

  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true
  config.treat_symbols_as_metadata_keys_with_true_values = true

  ##
  # Actions to perform before each example
  config.before(:each) do
    SandboxFileUtils.deactivate!(:noop)

    Open4.stubs(:popen4).raises('Unexpected call to Open4::popen4()')

    Backup::Utilities.send(:reset!)
    Backup::Config.send(:reset!)
    # Logger only queues messages received until Logger.start! is called.
    Backup::Logger.send(:initialize!)
  end
end

puts "\nRuby version: #{ RUBY_DESCRIPTION }\n\n"
