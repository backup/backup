# encoding: utf-8

Gem::Specification.new do |gem|

  ##
  # General configuration / information
  gem.name        = 'backup'
  gem.version     = '3.0.3.build.0'
  gem.platform    = Gem::Platform::RUBY
  gem.authors     = 'Michael van Rooijen'
  gem.email       = 'meskyanichi@gmail.com'
  gem.homepage    = 'http://rubygems.org/gems/backup'
  gem.summary     = 'Backup is a RubyGem (for UNIX-like operating systems: Linux, Mac OSX) that allows you to configure and perform backups in a simple manner using an elegant Ruby DSL.'
  gem.description = 'Backup is a RubyGem (for UNIX-like operating systems: Linux, Mac OSX) that allows you to configure and perform backups in a simple manner using an elegant Ruby DSL.
                    It supports various databases (MySQL, PostgreSQL, MongoDB and Redis), it supports various storage locations
                    (Amazon S3, Rackspace Cloud Files, Dropbox, any remote server through FTP, SFTP, SCP and RSync), it can archive files and folders,
                    it can cycle backups, it can do incremental backups, it can compress backups, it can encrypt backups (OpenSSL or GPG),
                    it can notify you about successful and/or failed backups. It is very extensible and easy to add new functionality to. It\'s easy to use.'

  # The Backup CLI executable
  gem.executables   = ['backup']

end
