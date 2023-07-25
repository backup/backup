#!/bin/sh
##
## The latest version of the bundler gem requires ruby 2.6 or better. Backup
## currently requires ruby 2.4.10. So I've hacked together a "quick-n-dirty"
## "bundler" script to install all the required gems into the ruby instance.
## 
##

echo "##############################################################################"
echo "Welcome to Jalopy Bundler: the crappy stand-in for the real bundler until"
echo "backup supports ruby 2.6.0 or better (or until a way is found to install a "
echo "version of the bundler gem that supports ruby 2.4.10)!"
echo "##############################################################################"



gem install thor -v 0.18
gem install open4 -v 1.3.0
gem install fog -v 1.42
gem install excon -v 0.71
gem install unf -v 0.1.3
gem install dropbox-sdk -v 1.6.5
gem install net-ssh -v 5.2.0
gem install net-scp -v 2.0.0
gem install net-sftp -v 2.1.2
gem install net-ftp -v 0.1.3
gem install net-smtp -v 0.1
gem install mail -v 2.6
gem install pagerduty -v 2.0.0
gem install twitter -v 6.0
gem install hipchat -v 1.0.1
gem install flowdock -v 0.4.0
gem install dogapi -v 1.40.0
gem install aws-sdk -v 2
gem install qiniu -v 6.5
gem install nokogiri -v 1.10

 # gems required for development
gem install rubocop -v 0.48.1
gem install rspec -v 3.8.0
gem install timecop -v 0.9.4
