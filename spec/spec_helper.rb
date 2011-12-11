# encoding: utf-8

##
# Use Bundler
require 'rubygems' if RUBY_VERSION < '1.9'
require 'bundler/setup'

##
# Load Backup
require 'backup'

##
# Use Mocha to mock with RSpec
require 'rspec'
RSpec.configure do |config|
  config.mock_with :mocha
  config.before(:each) do
    FileUtils.stubs(:mkdir_p)
    [:message, :error, :warn, :normal, :silent].each do |message_type|
      Backup::Logger.stubs(message_type)
    end
    Backup::Model.extension = 'tar'
  end
end

Backup.send(:remove_const, :TRIGGER) if defined? Backup::TRIGGER
Backup.send(:remove_const, :TIME) if defined? Backup::TIME

module Backup
  TRIGGER = 'myapp'
  TIME = Time.now.strftime("%Y.%m.%d.%H.%M.%S")
end

unless @_put_ruby_version
  puts @_put_ruby_version = "\n\nRuby version: #{RUBY_DESCRIPTION}\n\n"
end
