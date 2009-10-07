require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "backup"
    gem.summary = %Q{Backup is a gem/plugin that enables you to very easily create backups and transfer these to Amazon S3 or another server with SSH.}
    gem.description = %Q{
                          “Backup” is a RubyGem, written for Ruby on Rails. It's main purpose is to Backup any
                          files to Amazon S3 or any remotely accessible server through SSH (SCP). It supports database
                          and regular file backups. On top of that, it's extremely easy to set up. Backup will provide
                          a generator script that will place all necessary files inside your Rails application.
                          Two of which, are “yaml” configuration files. Using just these two files to configure a
                          backup for database formats such as a MySQL, SQLite3 or any Assets folder.
                          Setting up “Backup” takes only about a minute or two!
                        }
                        
    gem.email = "meskyan@gmail.com"
    gem.homepage = "http://github.com/meskyanichi/backup"
    gem.authors = ["meskyanichi"]
    gem.add_dependency "aws-s3"
    gem.add_dependency "net-ssh"
    gem.add_dependency "net-scp"
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
