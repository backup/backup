# encoding: utf-8

abort "These specs should only be run on the backup-testbox VM" unless
    %x[hostname].chomp == 'backup-testbox'

require 'bundler/setup'
require 'backup'

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each {|f| require f }

require 'rspec/autorun'
RSpec.configure do |config|
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true
  config.treat_symbols_as_metadata_keys_with_true_values = true

  config.include BackupSpec::ExampleHelpers

  config.before(:each) do
    # Reset to default paths
    Backup::Config.send(:reset!)
    # Remove default and alt config paths if they exist.
    FileUtils.rm_rf File.dirname(Backup::Config.config_file)
    FileUtils.rm_rf BackupSpec::ALT_CONFIG_PATH

    # Reset utility paths, the logger and clear previously loaded models.
    Backup::Utilities.send(:reset!)
    Backup::Logger.send(:reset!)
    Backup::Model.all.clear

    # Remove the local storage path if it exists.
    FileUtils.rm_rf BackupSpec::LOCAL_STORAGE_PATH

    @argv_save = ARGV
  end

  # The last spec example to run will leave behind it's files in the
  # LOCAL_STORAGE_PATH (if used) and it's config.rb and model files
  # in either the default path (~/Backup) or the alt path (~/Backup_alt)
  # so these files may be inspected if needed.
  #
  # Adding `:focus` to spec examples will automatically enable the
  # Console Logger so you can see the log output as the job runs.

  config.after(:each) do
    ARGV.replace(@argv_save)
  end
end

puts "\nRuby version: #{ RUBY_DESCRIPTION }\n\n"
