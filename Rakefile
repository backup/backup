require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "backup"
    gem.summary = %Q{Backup is a gem/plugin that enables you to very easily create backups and transfer these to Amazon S3 or another server with SSH.}
    gem.description = %Q{
                          Backup is a Ruby Gem, written specifically for Ruby on Rails applications. This gem offers a quick and easy way
                          to configure and run backups of your MySQL database (soon PostgreSQL and possibly more) and Archives (any files or folders)
                          to "Amazon S3" or "any remotely accessible server using SCP". Backup handles: Compression, Archiving, Encryption and Backup Cleaning.
                        }
                        
    gem.email = "meskyan@gmail.com"
    gem.homepage = ""
    gem.authors = ["Michael van Rooijen"]
    gem.add_dependency "aws-s3", ">= 0.6.2"
    gem.add_dependency "net-ssh", ">= 2.0.15"
    gem.add_dependency "net-scp", ">= 1.0.2"
    gem.add_dependency "sqlite3-ruby", ">= 1.2.5"
#    gem.files.include 'generators/**/*'
#    gem.files.include 'lib/**/*'
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
