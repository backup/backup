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
                            have access to, using either SCP, SFTP or regular FTP. Backup handles Compression, Archiving, Encryption,
                            Backup Cleaning (Cycling) and supports Email Notifications.
                        }
                        
    gem.email = "meskyanichi@gmail.com"
    gem.homepage = "http://final-creation.com/open-source"
    gem.authors = ["Michael van Rooijen", "Fernando Migliorini Luizão"]
    gem.add_dependency "activerecord",  ">= 2.3.5"
    gem.add_dependency "sqlite3-ruby",  ">= 1.2.5"
    gem.add_dependency "hirb",          ">= 0.2.9"
    gem.add_dependency "pony",          ">= 0.5"
    
  end
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList['spec/**/*_spec.rb']
  t.spec_opts = %w(-fp --color)
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

task :default => :spec

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
