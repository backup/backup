# encoding: utf-8

# To run the test suite against all 3 rubies: 1.9.3, 1.9.2, and 1.8.7, simply run the following command:
#
# $ guard start
#
# Be use you are using RVM and have Ruby 1.9.3, 1.9.2, 1.8.7 installed as well as all of Backup's gem
# dependencies for each of these Ruby versions.
#
# Be sure to run `bundle install` against every Ruby version, as well as `gem install thor POpen4`

guard "rspec",
  :rvm     => ["1.9.3", "1.9.2", "1.8.7"],
  :cli     => "--color --format Fuubar",
  :notification   => false,
  :all_after_pass => false,
  :all_on_start   => false do

  watch("lib/backup.rb")            { "spec" }
  watch("spec/spec_helper.rb")      { "spec" }
  watch(%r{^lib/backup/(.+)\.rb}) {|m| "spec/#{ m[1] }_spec.rb" }
  watch(%r{^spec/.+_spec\.rb})
end
