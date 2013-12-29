# encoding: utf-8

guard "rspec",
  :interactor       => :off,
  :notification     => false,
  :failed_mode      => :none,
  :all_after_pass   => false,
  :all_on_start     => false do

  watch("lib/backup.rb")          { "spec" }
  watch("spec/spec_helper.rb")    { "spec" }
  watch(%r{^lib/backup/(.+)\.rb}) {|m| "spec/#{ m[1] }_spec.rb" }
  watch(%r{^spec/.+_spec\.rb})

  watch(%r{^lib/backup/(.+)\/base.rb}) {|m| "spec/#{ m[1] }" }
  watch(%r{^spec/support/shared_examples/(.+)\.rb}) {|m| "spec/#{ m[1] }" }
end
