# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/lib/backup')

Gem::Specification.new do |gem|

  ##
  # General configuration / information
  gem.name        = 'backup'
  gem.version     = Backup::Version.current
  gem.platform    = Gem::Platform::RUBY
  gem.authors     = 'Michael van Rooijen'
  gem.email       = 'meskyanichi@gmail.com'
  gem.homepage    = 'http://rubygems.org/gems/backup'
  gem.summary     = 'Backup is a RubyGem (for UNIX-like operating systems: Linux, Mac OSX)
                    that allows you to configure and perform backups in a simple manner using
                    an elegant Ruby DSL. It supports various databases (MySQL, PostgreSQL, MongoDB and Redis),
                    it supports various storage locations (Amazon S3, Rackspace Cloud Files, Dropbox, any remote
                    server through FTP, SFTP, SCP and RSync), it provide Syncers (RSync, S3) for efficient backups,
                    it can archive files and directories, it can cycle backups, it can do incremental backups, it
                    can compress backups, it can encrypt backups (OpenSSL or GPG), it can notify you about
                    successful and/or failed backups (Email, Twitter and Campfire). It is very extensible and easy to add new
                    functionality to. It\'s easy to use.'

  ##
  # Files and folder that need to be compiled in to the Ruby Gem
  gem.files         = %x[git ls-files].split("\n")
  gem.test_files    = %x[git ls-files -- {spec}/*].split("\n")
  gem.require_path  = 'lib'

  ##
  # The Backup CLI executable
  gem.executables   = ['backup']

  ##
  # Production gem dependencies
  gem.add_dependency 'thor', ['~> 0.14.6']

end
