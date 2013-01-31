# encoding: utf-8

# RubyGems Source
source 'http://rubygems.org'

# Include gem dependencies from the gemspec for development purposes
gemspec

# Dynamically define the dependencies specified in Backup::Dependency.all
require File.expand_path("../lib/backup/dependency", __FILE__)
Backup::Dependency.all.each do |name, gemspec|
  gem(name, gemspec[:version])
end

gem 'rspec'
gem 'mocha', '0.12.7'
gem 'timecop'
gem 'fuubar'

gem 'guard'
gem 'guard-rspec'
gem 'rb-fsevent' # guard notifications for osx
gem 'growl'      # $ brew install growlnotify
gem 'rb-inotify' # guard notifications for linux
gem 'libnotify'  # $ apt-get install ???

gem 'yard'
gem 'redcarpet'
