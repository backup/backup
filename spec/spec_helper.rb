# encoding: utf-8

##
# Use Bundler
require 'rubygems' if RUBY_VERSION < '1.9'
require 'bundler/setup'

##
# Load Backup
require 'backup'

require 'timecop'

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

  ##
  # Actions to perform before each example
  config.before(:each) do
    FileUtils.collect_method(:noop).each do |method|
      FileUtils.stubs(method).raises("Unexpected call to FileUtils.#{method}")
    end
    Open4.stubs(:popen4).raises('Unexpected call to CLI::Helpers.run()')

    [:message, :error, :warn, :normal, :silent].each do |message_type|
      Backup::Logger.stubs(message_type)
    end
  end
end

unless @_put_ruby_version
  puts @_put_ruby_version = "\n\nRuby version: #{RUBY_DESCRIPTION}\n\n"
end
