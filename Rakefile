require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "backup"
    gem.summary = %Q{Backup is a Ruby Gem that simplifies making backups for databases, files and folders.}
    gem.description = %Q{
                            Backup is a Ruby Gem written for Unix and Rails environments. It can be used both with and without the
                            Ruby on Rails framework! This gem offers a quick and simple solution to backing up databases such as
                            MySQL/PostgreSQL and Files/Folders. All backups can be transferred to Amazon S3 or any remote server you
                            have access to, using either SCP, SFTP or regular FTP. Backup handles Compression, Archiving, Encryption
                            and Backup Cleaning (Cycling).
                        }
                        
    gem.email = "meskyan@gmail.com"
    gem.homepage = "http://final-creation.com/open-source"
    gem.authors = ["Michael van Rooijen"]
    gem.add_dependency "aws-s3",        ">= 0.6.2"
    gem.add_dependency "net-ssh",       ">= 2.0.15"
    gem.add_dependency "net-scp",       ">= 1.0.2"
    gem.add_dependency "net-sftp",      ">= 2.0.4"
    gem.add_dependency "activerecord",  ">= 2.3.5"
    gem.add_dependency "sqlite3-ruby",  ">= 1.2.5"
    gem.add_dependency "hirb",          ">= 0.2.9"
    gem.add_dependency "pony",          ">= 0.5"
    
  end
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/*_test.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  if File.exist?('VERSION')
    version = File.read('VERSION')
  else
    version = ""
  end

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "backup #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
