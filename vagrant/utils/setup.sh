#!/usr/bin/env bash

if [[ ! `hostname` == "backup-testbox" ]]; then
  echo "This script should only be run on the VM"
  exit
fi

# This script may also be called any time you install/update a gem
# to easily install/update it for the other ruby versions.

sync_gem_cache() {
  cp -n ~/.gem/ruby/2.0.0/cache/*.gem ~/.gem/ruby/1.9.3/cache/
  cp -n ~/.gem/ruby/2.0.0/cache/*.gem ~/.gem/ruby/1.9.2/cache/
  cp -n ~/.gem/ruby/1.9.3/cache/*.gem ~/.gem/ruby/2.0.0/cache/
  cp -n ~/.gem/ruby/1.9.3/cache/*.gem ~/.gem/ruby/1.9.2/cache/
  cp -n ~/.gem/ruby/1.9.2/cache/*.gem ~/.gem/ruby/2.0.0/cache/
  cp -n ~/.gem/ruby/1.9.2/cache/*.gem ~/.gem/ruby/1.9.3/cache/
}

cd /vagrant/utils

echo -n "==> Checking Spec Utils Environment... "
chruby-exec 2.0 -- bundle check >/dev/null 2>&1
if [[ $? == "0" ]]; then
  echo "OK"
else
  echo "Installing Gems..."
  chruby-exec 2.0 -- bundle install
  echo "Preparing VM Environment..."
  chruby-exec 2.0 -- rake all
fi

cd /vagrant

echo -n "==> Checking Ruby 2.0 Test Environment... "
chruby-exec 2.0 -- bundle check >/dev/null 2>&1
if [[ $? == "0" ]]; then
  echo "OK"
else
  echo "Installing Gems..."
  sync_gem_cache
  chruby-exec 2.0 -- bundle install
fi

echo -n "==> Checking Ruby 1.9.3 Test Environment... "
chruby-exec 1.9.3 -- bundle check >/dev/null 2>&1
if [[ $? == "0" ]]; then
  echo "OK"
else
  echo "Installing Gems..."
  sync_gem_cache
  chruby-exec 1.9.3 -- bundle install
fi

echo -n "==> Checking Ruby 1.9.2 Test Environment... "
chruby-exec 1.9.2 -- bundle check >/dev/null 2>&1
if [[ $? == "0" ]]; then
  echo "OK"
else
  echo "Installing Gems..."
  sync_gem_cache
  chruby-exec 1.9.2 -- bundle install
fi

echo -e "\n== System Ready! =="
