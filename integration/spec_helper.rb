# encoding: utf-8

require "backup"

Dir[File.expand_path("../support/**/*.rb", __FILE__)].each { |f| require f }

RSpec.configure do |c|
  c.include BackupSpec::ExampleHelpers
end
