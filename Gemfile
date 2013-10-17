# encoding: utf-8

source 'https://rubygems.org'

##
# Gemfile.lock controls the dependencies used when running the specs in `spec/`.
#
# backup.gemspec controls the dependencies that will be installed and used by
# the released version of backup. It also controls the dependencies used when
# running the specs in `vagrant/spec`, which are run on the VM.
#
# Whenever Gemfile.lock is updated, `rake gemspec` must be run to sync
# backup.gemspec with Gemfile.lock. All gems in the :production group
# (and their dependencies) will be added to backup.gemspec.
##

# Specify version requirements to control `bundle update` if needed.
group :production do
  gem 'thor'
  gem 'open4'
  gem 'fog', '= 1.13.0' # see https://github.com/fog/fog/pull/1905
  gem 'excon'
  gem 'dropbox-sdk', '= 1.5.1' # patched
  gem 'net-ssh'
  gem 'net-scp'
  gem 'net-sftp'
  gem 'mail', '= 2.5.4' # patched
  gem 'twitter'
  gem 'hipchat'
  gem 'json'
end

gem 'rspec'
gem 'fuubar'
gem 'mocha'
gem 'timecop', '= 0.6.1' # ruby-1.8.7 support was removed in 0.6.2

# Omitted from Travis CI Environment
group :no_ci do
  gem 'guard'
  gem 'guard-rspec'
  gem 'listen', '~> 1.0' # for ruby-1.8.7 and 1.9.2

  gem 'rb-fsevent' # Mac OS X
  gem 'rb-inotify' # Linux

  gem 'yard'
  gem 'redcarpet', '< 3.0' # < 3.0 for ruby-1.8.7
end
