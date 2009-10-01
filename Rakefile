require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "backup"
    gem.summary = %Q{Backup is a gem/plugin that enables you to very easily create backups and transfer these to Amazon S3 or another server with SSH.}
    gem.description = %Q{Backup is a gem/plugin that enables you to very easily create backups and transfer these to Amazon S3 or another server with SSH.
                        It currently supports MySQL, SQLite3 and basic Assets (documents, images, etc). The files will get tar'd / gzip'd and get a timestamp.
                        After creation, these files can be transferred to either Amazon S3 or any remote server through SSH.}
    gem.email = "meskyan@gmail.com"
    gem.homepage = "http://github.com/meskyanichi/backup"
    gem.authors = ["meskyanichi"]
    gem.add_development_dependency "aws-s3"
    gem.files.include 'generators/**/*'
    gem.files.include 'lib/**/*'
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
