# encoding: utf-8

# RubyGems Source
source 'http://rubygems.org'

# Include gem dependencies from the gemspec for development purposes
gemspec

# Dynamically define the dependencies specified in Backup::Dependency.all
require File.expand_path("../lib/backup/dependency", __FILE__)
Backup::Dependency.all.each do |dep|
  gem(dep.name, *dep.requirements)
end

gem 'rspec'
gem 'mocha'
gem 'timecop'

# Omitted from Travis CI Environment
group :development do
  gem 'guard'
  gem 'guard-rspec'
  gem 'fuubar'

  gem 'rb-fsevent', :require => false # Mac OS X
  gem 'rb-inotify', :require => false # Linux

  gem 'yard'
  gem 'redcarpet'
end

