# frozen_string_literal: true

# hacky: add parent-level backup gem to load path
# $:.unshift File.expand_path("../../../../lib", __FILE__)

require "backup"
require "backup_fog"
require "backup/cloud_io/s3"

require "timecop"

require "fog"

Dir[File.expand_path("../support/**/*.rb", __FILE__)].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
