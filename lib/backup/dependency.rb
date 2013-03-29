# encoding: utf-8

module Backup
  ##
  # A little self-contained gem manager for Backup.
  # Rather than specifying hard dependencies in the gemspec, forcing users to
  # install gems they do not want/need, Backup will notify them when a gem has
  # not been installed, or version is incorrect, and provide the command to
  # install the gem. These dependencies are dynamically loaded in the Gemfile.
  class Dependency
    DEPENDENCIES = {
      'fog' => {
        :require => 'fog',
        :version => '~> 1.9.0',
        :for     => 'Amazon S3, Rackspace Cloud Files (S3, CloudFiles Storages)',
        :dependencies  => ['net-ssh', 'net-scp', 'excon']
      },

      'excon' => {
        :require => 'excon',
        :version => '~> 0.17.0',
        :for     => 'HTTP Connection Support for Storages/Syncers'
      },

      'dropbox-sdk' => {
        :require => 'dropbox_sdk',
        :version => '~> 1.5.1',
        :for     => 'Dropbox Web Service (Dropbox Storage)'
      },

      'net-sftp' => {
        :require => 'net/sftp',
        :version => ['>= 2.0.0', '<= 2.0.5'],
        :for     => 'SFTP Protocol (SFTP Storage)',
        :dependencies  => 'net-ssh'
      },

      'net-scp' => {
        :require => 'net/scp',
        :version => ['>= 1.0.0', '<= 1.0.4'],
        :for     => 'SCP Protocol (SCP Storage)',
        :dependencies  => 'net-ssh'
      },

      'net-ssh' => {
        :require => 'net/ssh',
        :version => ['>= 2.3.0', '<= 2.5.2'],
        :for     => 'SSH Protocol (SSH Storage)'
      },

      'mail' => {
        :require => 'mail',
        :version => '~> 2.5.0',
        :for     => 'Sending Emails (Mail Notifier)'
      },

      'twitter' => {
        :require => 'twitter',
        :version => '~> 4.5.0',
        :for     => 'Sending Twitter Updates (Twitter Notifier)'
      },

      'httparty' => {
        :require => 'httparty',
        :version => '~> 0.10.2',
        :for     => 'Sending Http Updates (Campfire Notifier)'
      },

      'prowler' => {
        :require => 'prowler',
        :version => '~> 1.3.1',
        :for     => 'Sending iOS push notifications (Prowl Notifier)'
      },

      'hipchat' => {
        :require => 'hipchat',
        :version => '~> 0.7.0',
        :for     => 'Sending notifications to Hipchat'
      },

      'parallel' => {
        :require => 'parallel',
        :version => '~> 0.6.0',
        :for     => 'Adding concurrency to Cloud-based syncers.'
      }
    }

    class << self
      def all
        @all ||= []
      end

      def find(name)
        all.select {|dep| dep.name == name }.first
      end

      def load(name)
        find(name).load!
      end
    end

    attr_reader :name, :require_as, :used_for, :requirements

    def initialize(name, options = {})
      @name = name
      @require_as     = options[:require]
      @requirements   = Array(options[:version])
      @dependencies   = Array(options[:dependencies])
      @used_for       = options[:for]
    end

    # dependencies should be defined in the order
    # they should be installed or loaded.
    def dependencies
      @dependencies.map {|name| self.class.find(name) }
    end

    def load!
      dependencies.each(&:load!)

      gem(name, *requirements)
      require require_as
    rescue LoadError
      raise Errors::Dependency::LoadError, <<-EOS
        Dependency Missing
        Gem Name: #{ name }
        Used for: #{ used_for }

        To install the gem, issue the following command:
        > backup dependencies --install #{ name }
        Please try again after installing the missing dependency.
      EOS
    end

    def installed?
      Gem::Specification.find_by_name(name, *requirements)
      true
    rescue LoadError
      false
    end

    # If multiple version requirements are defined, this tries to find the
    # version that matches them all. Otherwise, it will fallback to installing
    # based on the last requirement. This should only be called from the CLI
    # for `backup dependencies --install <name>`.
    def install!
      version = nil
      if requirements.count > 1
        begin
          require 'rubygems/dependency_installer'
          inst = Gem::DependencyInstaller.new
          spec, _ = inst.find_spec_by_name_and_version(name, *requirements).first
          version = spec.version
        rescue
        end
      end
      version ||= requirements.last
      command = "gem install --no-ri --no-rdoc #{ name } -v '#{ version }'"
      puts "\nLaunching `#{ command }`"
      exec command
    end

    DEPENDENCIES.each {|name, options| all << new(name, options) }
  end
end
