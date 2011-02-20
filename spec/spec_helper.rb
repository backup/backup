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

Object.send(:remove_const, :TRIGGER) if defined? TRIGGER
TRIGGER = 'myapp'

Object.send(:remove_const, :TIME) if defined? TIME
TIME = Time.now.strftime("%Y.%m.%d.%H.%M.%S")
