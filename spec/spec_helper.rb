# encoding: utf-8

##
# Load Backup
require File.expand_path( '../../lib/backup', __FILE__ )

##
# Use Mocha to mock with RSpec
RSpec.configure do |config|
  config.mock_with :mocha
end

# FIXTURES_PATH = File.join( File.dirname(__FILE__), 'fixtures' )

Backup.send(:remove_const, :TRIGGER) if defined? Backup::TRIGGER
Backup.send(:remove_const, :TIME) if defined? Backup::TIME

module Backup
  TRIGGER = 'myapp'
  TIME = Time.now.strftime("%Y.%m.%d.%H.%M.%S")
end

unless @put_ruby_version
  puts @put_ruby_version = "\n\nRuby version: #{ENV['rvm_ruby_string']}\n\n"
end

Backup::Logger.stubs(:to_file)