Gem::Specification.new do |gem|
  
  ##
  # Gem Specifications
  gem.name        = 'backup'
  gem.version     = '2.3.2.pre'
  gem.date        = Date.today.to_s
  gem.summary     = 'Backup is a Ruby Gem that simplifies making backups for databases, files and folders.'
  gem.description = 'Backup is a Ruby Gem written for Unix and Rails environments. It can be used both with and without the
  Ruby on Rails framework! This gem offers a quick and simple solution to backing up databases such as
  MySQL/PostgreSQL and Files/Folders. All backups can be transferred to Amazon S3 or any remote server you
  have access to, using either SCP, SFTP or regular FTP. Backup handles Compression, Archiving, Encryption
  and Backup Cleaning (Cycling).'
  
  ##
  # Author specifications
  gem.authors  = ['Michael van Rooijen']
  gem.email    = 'meskyanichi@gmail.com'
  gem.homepage = 'http://github.com/meskyanichi/backup'
  
  ##
  # Files to be compiled
  gem.files = ['README.textile', 'CHANGELOG', 'LICENSE', 'VERSION'] +
              Dir['lib/**/*'] + Dir['bin/*'] + Dir['generators/**/*'] + Dir['setup/*']
  
  ##
  # Load Path
  gem.require_path = 'lib'

  ##
  # Executables
  gem.executables = ['backup']
  
  ##
  # Dependencies
  gem.add_dependency('s3',        [">= 0.3.0"])
  gem.add_dependency('net-ssh',       [">= 2.0.15"])
  gem.add_dependency('net-scp',       [">= 1.0.2"])
  gem.add_dependency('net-sftp',      [">= 2.0.4"])
  gem.add_dependency('activerecord',  [">= 2.3.5"])
  gem.add_dependency('sqlite3-ruby',  ["= 1.2.5"])
  gem.add_dependency('hirb',          [">= 0.2.9"])
  gem.add_dependency('pony',          [">= 0.5"])
end