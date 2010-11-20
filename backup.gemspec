lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'date'
require 'backup/version'

Gem::Specification.new do |gem|
  
  ##
  # Gem Specifications
  gem.name        = 'backup'
  gem.version     = Backup::VERSION
  gem.date        = Date.today.to_s
  gem.summary     = 'Backup is a Ruby Gem that simplifies making backups for databases, files and folders.'
  gem.description = 'Backup is a Ruby Gem written for Unix and Ruby on Rails (2 and 3) environments. It can be used both with
  and without the Ruby on Rails framework! This gem offers a quick and simple solution to backing up databases
  such as MySQL/PostgreSQL/SQLite and Files/Folders. All backups can be transferred to Amazon S3, Rackspace Cloud Files,
  Dropbox Web Service, any remote server you have access to (using either SCP, SFTP or regular FTP), or a Local server.
  Backup handles Compression, Archiving, Encryption (OpenSSL or GPG), Backup Cleaning (Cycling) and supports Email Notifications.'
  
  ##
  # Author specifications
  gem.authors  = ['Michael van Rooijen']
  gem.email    = 'meskyanichi@gmail.com'
  gem.homepage = 'http://github.com/meskyanichi/backup'
  
  ##
  # Files to be compiled
  gem.files = ['README.md', 'CHANGELOG', 'LICENSE'] +
              Dir['lib/**/*'] + Dir['bin/*'] + Dir['generators/**/*'] + Dir['setup/*']
  
  ##
  # Load Path
  gem.require_path = 'lib'
  
  ##
  # Executables
  gem.executables = ['backup']
  
  ##
  # Dependencies
  gem.add_dependency('fog',           ["~> 0.3.5"])
  gem.add_dependency('json_pure',     ["~> 1.4.6"])
  gem.add_dependency('net-ssh',       [">= 2.0.15"])
  gem.add_dependency('net-scp',       [">= 1.0.2"])
  gem.add_dependency('net-sftp',      [">= 2.0.4"])
  gem.add_dependency('activerecord',  [">= 2.3.5"])
  gem.add_dependency('sqlite3-ruby',  [">= 1.2.5"])
  gem.add_dependency('hirb',          [">= 0.2.9"])
  gem.add_dependency('pony',          [">= 0.5"])
  gem.add_dependency('cloudfiles',    [">= 1.4.7"])
  gem.add_dependency('dropbox',       [">= 1.1.2"])
end
