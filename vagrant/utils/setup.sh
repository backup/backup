#!/usr/bin/env bash

if [[ ! `hostname` == "backup-testbox" ]]; then
  echo "This script should only be run on the VM"
  exit
fi

cd /vagrant/utils

echo -n "==> Checking Spec Utils Environment... "
bundle check >/dev/null 2>&1
if [[ $? == "0" ]]; then
  echo "OK"
else
  echo "Installing Gems..."
  bundle install
  echo "Preparing VM Environment..."
  rake all
fi

cd /vagrant

echo -n "==> Checking Ruby 2.0 Test Environment... "
bundle check >/dev/null 2>&1
if [[ $? == "0" ]]; then
  echo "OK"
else
  echo "Installing Gems..."
  bundle install
fi

echo -n "==> Checking Ruby 1.9.3 Test Environment... "
chruby-exec 1.9.3 -- bundle check >/dev/null 2>&1
if [[ $? == "0" ]]; then
  echo "OK"
else
  echo "Installing Gems..."
  chruby-exec 1.9.3 -- bundle install
fi

echo -n "==> Checking Ruby 1.9.2 Test Environment... "
chruby-exec 1.9.2 -- bundle check >/dev/null 2>&1
if [[ $? == "0" ]]; then
  echo "OK"
else
  echo "Installing Gems..."
  chruby-exec 1.9.2 -- bundle install
fi

echo -e "\n== System Ready! =="
