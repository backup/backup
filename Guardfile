# encoding: utf-8

ENV['GUARD_NOTIFY'] = 'false'
guard "rspec",
  :cli     => "--color --format Fuubar",
  :all_after_pass => false,
  :all_on_start   => false,
  :keep_failed    => false do

  watch("lib/backup.rb")            { "spec" }
  watch("spec/spec_helper.rb")      { "spec" }
  watch(%r{^lib/backup/(.+)\.rb}) {|m| "spec/#{ m[1] }_spec.rb" }
  watch(%r{^spec/.+_spec\.rb})
end
