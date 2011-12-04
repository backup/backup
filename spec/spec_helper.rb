# encoding: utf-8

##
# Load Backup
require File.expand_path( '../../lib/backup', __FILE__ )

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
  puts @_put_ruby_version = "\n\nRuby version: #{ENV['rvm_ruby_string']}\n\n"
end
