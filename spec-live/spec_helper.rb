# encoding: utf-8

## # Use Bundler
require 'rubygems' if RUBY_VERSION < '1.9'
require 'bundler/setup'

##
# Load Backup
require 'backup'

module Backup
  module SpecLive
    PATH = File.expand_path('..', __FILE__)
    # to archive local backups, etc...
    TMP_PATH = PATH + '/tmp'
    SYNC_PATH = PATH + '/sync'

    config = PATH + '/backups/config.yml'
    if File.exist?(config)
      CONFIG = YAML.load_file(config)
    else
      puts "The 'spec-live/backups/config.yml' file is required."
      puts "Use 'spec-live/backups/config.yml.template' to create one"
      exit!
    end

    module ExampleHelpers

      def h_set_trigger(trigger)
        Backup::Logger.clear!
        Backup::Model.all.clear
        Backup::Config.load_config!
        FileUtils.mkdir_p(File.join(Backup::Config.data_path, trigger))
        Backup::Model.find(trigger)
      end

      def h_clean_data_paths!
        paths = [:data_path, :log_path, :tmp_path ].map do |name|
          Backup::Config.send(name)
        end + [Backup::SpecLive::TMP_PATH]
        paths.each do |path|
          h_safety_check(path)
          FileUtils.rm_rf(path)
          FileUtils.mkdir_p(path)
        end
      end

      def h_safety_check(path)
        # Rule #1: Do No Harm.
        unless (
          path.start_with?(Backup::SpecLive::PATH) &&
            Backup::SpecLive::PATH.end_with?('spec-live')
        ) || path.include?('spec_live_test_dir')
          warn "\nSafety Check Failed:\nPath: #{path}\n\n" +
              caller(1).join("\n")
          exit!
        end
      end

    end # ExampleHelpers
  end

  Config.update(:root_path => SpecLive::PATH + '/backups')

  Logger.quiet = true unless ENV['VERBOSE']
end

##
# Use Mocha to mock with RSpec
require 'rspec'
RSpec.configure do |config|
  config.mock_with :mocha
  config.include Backup::SpecLive::ExampleHelpers
  config.before(:each) do
    h_clean_data_paths!
    if ENV['VERBOSE']
      /spec-live\/(.*):/ =~ self.example.metadata[:example_group][:block].inspect
      puts "\n\nSPEC: #{$1}"
      puts "DESC: #{self.example.metadata[:full_description]}"
      puts '-' * 78
    end
  end
end

puts "\n\nRuby version: #{RUBY_DESCRIPTION}\n\n"
