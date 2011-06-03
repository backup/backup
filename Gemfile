##
# RubyGems Source
source 'http://rubygems.org'

##
# Load Backup::Dependency
%w[cli dependency].each do |path|
  require File.expand_path("../lib/backup/#{path}", __FILE__)
end

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
  gem 'timecop'
  gem 'fuubar'

  gem 'guard'
  gem 'guard-rspec'
  gem 'rb-fsevent' # guard notifications for osx 
  gem 'growl'      # $ brew install growlnotify
  gem 'rb-inotify' # guard notifications for linux
  gem 'libnotify'  # $ apt-get install ???
end