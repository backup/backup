require "rake/clean"
require "rubocop/rake_task"

CLEAN.include("tmp")
CLOBBER.include("tmp", "*.gem")

RuboCop::RakeTask.new

desc "Open a pry console in the Backup context"
task :console do
  require "pry"
  require "backup"
  ARGV.clear
  Pry.start || exit
end

def version_file
  File.join(File.expand_path("lib/backup/version.rb"))
end

def current_version
  Backup.send(:remove_const, :VERSION)
  load version_file
  Backup::VERSION
end

# Validates version numbers
#
# Valid version number format:
# - 10.0.0
# - 10.0.1.alpha
# - 10.0.1.alpha.1
# - 10.0.1.beta
# - 10.0.1.beta.1
# - 10.0.1.rc
# - 10.0.1.rc.1
def valid_version?(version)
  version =~ /\d+\.\d+\.\d+(\.(alpha|beta|rc)(\.\d+)?)?/
end

def current_branch
  `git rev-parse --abbrev-ref HEAD`.chomp
end

desc "Release new Backup gem version. Use this to release a new version."
task :release do # rubocop:disable Metrics/BlockLength
  puts "Current version: #{current_version}"
  print "Enter new version: "
  new_version = $stdin.gets.chomp

  unless valid_version?(new_version)
    abort "ERROR: Invalid version number: #{new_version.inspect}"
  end

  puts "Creating new version: #{new_version}"

  lines = File.readlines(version_file)
  File.open(version_file, "w+") do |file|
    lines.each do |line|
      if line =~ /VERSION =/
        file.puts %(  VERSION = "#{new_version}")
      else
        file.write line
      end
    end
  end

  # Check if file saved correctly
  unless current_version == new_version
    abort "ERROR: Versions don't match!\n"\
      "Current version:#{current_version}\n"\
      "New version: #{new_version}"
  end

  puts `gem build backup.gemspec`

  puts "Pushing to repository.."
  puts `git commit -m "Release v#{new_version} [ci skip]" #{version_file}`
  puts `git tag #{new_version}`
  puts `git push origin #{new_version} #{current_branch}`

  puts "Publishing Backup version #{new_version}"
  puts `gem push backup-#{new_version}.gem`

  puts "Backup version #{new_version} released!"
end

namespace :docker do
  namespace :test do
    directory "tmp"
    directory "tmp/test_data"

    desc "Run integration tests inside a container"
    task integration: [:build, "tmp", "tmp/test_data"] do
      sh "docker run -e RUBYPATH='/usr/local/bundle/bin:/usr/local/bin' " \
        "-v $PWD:/usr/src/backup " \
        "-it backup_runner:latest ruby -Ilib -S rspec ./integration/acceptance/"
    end

    desc "Build an image for testing"
    task :build do
      sh "docker build -t backup_runner:latest ."
    end

    desc "Remove unused images, and all containers"
    task :clean do
      containers = `docker ps -a -q`
      unless containers.empty?
        `docker stop $(docker ps -a -q)`
        `docker rm $(docker ps -a -q)`
      end
      `docker images -qf dangling=true | xargs docker rmi`
    end

    desc "Start a container with a shell"
    task shell: [:build] do
      sh "docker run -e RUBYPATH='/usr/local/bundle/bin:/usr/local/bin' " \
         "-v $PWD:/usr/src/backup -it backup_runner:latest /bin/bash"
    end

    desc "Run RSpec tests inside a container"
    task spec: [:build] do
      sh "docker run -e RUBYPATH='/usr/local/bundle/bin:/usr/local/bin' " \
         "-v $PWD:/usr/src/backup " \
         "-it backup_runner:latest ruby -Ilib -S rspec ./spec/"
    end
  end
end
