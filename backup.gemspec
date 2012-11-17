# encoding: utf-8

require File.expand_path('lib/backup/version')

Gem::Specification.new do |gem|

  ##
  # General configuration / information
  gem.name        = 'backup'
  gem.version     = Backup::Version.current
  gem.platform    = Gem::Platform::RUBY
  gem.authors     = 'Michael van Rooijen'
  gem.email       = 'meskyanichi@gmail.com'
  gem.homepage    = 'http://rubygems.org/gems/backup'
  gem.summary     = 'Backup is a RubyGem, written for UNIX-like operating systems, that allows you to easily perform backup operations on both your remote and local environments. It provides you with an elegant DSL in Ruby for modeling your backups. Backup has built-in support for various databases, storage protocols/services, syncers, compressors, encryptors and notifiers which you can mix and match. It was built with modularity, extensibility and simplicity in mind.'

  ##
  # Files and folder that need to be compiled in to the Ruby Gem
  gem.files         = %x[git ls-files].split("\n")
  gem.test_files    = %x[git ls-files -- {spec}/*].split("\n")
  gem.require_path  = 'lib'

  ##
  # The Backup CLI executable
  gem.executables   = ['backup']

  ##
  # Gem dependencies
  gem.add_dependency 'thor',  ['>= 0.15.4', '< 2']
  gem.add_dependency 'open4', ['~> 1.3.0']

end
