##
# RubyGems Source
source 'http://rubygems.org'

##
# Load Backup::Dependency
require File.expand_path("../lib/backup/dependency", __FILE__)

##
# Dynamically define the dependencies specified in Backup::Dependency.all
Backup::Dependency.all.each do |name, gemspec|
  gem(name, gemspec[:version])
end

##
# Define gems to be used in the 'test' environment
group :test do
  gem 'rspec'
  gem 'mocha'
  gem 'infinity_test'
  gem 'fuubar'
  gem 'timecop'
end