# encoding: utf-8

## # Use Bundler
require 'rubygems' if RUBY_VERSION < '1.9'
require 'bundler/setup'

##
# Load Backup
require 'backup'

# Backup::SpecLive::GPGKeys
# Loaded here so these are available in backups/models.rb
# as well as within encryptor/gpg_spec.rb
require File.expand_path('../encryptor/gpg_keys.rb', __FILE__)

module Backup
  module SpecLive
    PATH = File.expand_path('..', __FILE__)
    # to archive local backups, etc...
    TMP_PATH = PATH + '/tmp'
    SYNC_PATH = PATH + '/sync'

    ARCHIVE_JOB = lambda do |archive|
      archive.add     File.expand_path('../../lib/backup', __FILE__)
      archive.exclude File.expand_path('../../lib/backup/storage', __FILE__)
    end

    config = PATH + '/backups/config.yml'
    if File.exist?(config)
      CONFIG = YAML.load_file(config)
    else
      puts "The 'spec-live/backups/config.yml' file is required."
      puts "Use 'spec-live/backups/config.yml.template' to create one"
      exit!
    end

    class << self
      attr_accessor :load_models
    end

    module ExampleHelpers

      # This method loads all defaults in config.rb and all the Models
      # in models.rb, then returns the Model for the given trigger.
      def h_set_trigger(trigger)
        Backup::SpecLive.load_models = true
        Backup::Logger.clear!
        Backup::Model.all.clear
        Backup::Config.load_config!
        model = Backup::Model.find(trigger)
        model.prepare!
        model
      end

      # This method can be used to setup a test where you need to setup
      # and perform a single Model that can not be setup in models.rb.
      # This is primarily for Models used to test deprecations, since
      # those warnings will be output when the Model is instantiated
      # and will pollute the output of all other tests.
      #
      # Usage:
      #   model = h_set_single_model do
      #     Backup::Model.new(:test_trigger, 'test label') do
      #       ...setup model...
      #     end
      #   end
      #
      # The block doesn't have to return the model, as it will be retrieved
      # from Model.all (since it will be the only one).
      #
      # Remember when defining the model that the DSL constants won't be
      # available, as the block is not being evaluated in the context of
      # the Backup::Config module. So, just use strings instead.
      # e.g. store_with 'Local' vs store_with Local
      #
      # Note this will still load any defaults setup in config.rb, so don't
      # do anything in config.rb that would generate a deprecation warning :)
      #
      def h_set_single_model(&block)
        Backup::SpecLive.load_models = false
        Backup::Logger.clear!
        Backup::Model.all.clear
        Backup::Config.load_config!
        block.call
        model = Backup::Model.all.first
        model.prepare!
        model
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

puts "\nRuby version: #{ RUBY_DESCRIPTION }\n"

unless ENV['VERBOSE']
  puts <<-EOS

    Some of these tests can be slow, so be patient.
    It's recommended you run these with:
      $ VERBOSE=1 rspec spec-live/
    For some tests, [error] and [warning] messages are normal.
    Some could pass, but still have problems.
    So, pay attention to the messages :)

  EOS
end
