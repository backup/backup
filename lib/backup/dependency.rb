# encoding: utf-8

module Backup

  ##
  # A little self-contained gem manager for Backup.
  # Rather than specifying hard dependencies in the gemspec, forcing users
  # to install gems they do not want/need, Backup will notify them when a gem
  # has not been installed, or when the gem's version is incorrect, and provide the
  # command to install the gem. These dependencies are dynamically loaded in the Gemfile
  class Dependency

    ##
    # Returns a hash of dependencies that Backup requires
    # in order to run every available feature
    def self.all
      {
        'fog'      => '~> 0.6.0',  # Amazon S3, Rackspace Cloud Files
        'dropbox'  => '~> 1.2.3',  # Dropbox
        'net-sftp' => '~> 2.0.5',  # SFTP Protocol
        'net-scp'  => '~> 1.0.4',  # SCP Protocol
        'net-ssh'  => '~> 2.1.3',  # SSH Protocol
        'mail'     => '~> 2.2.15', # Mail
        'twitter'  => '~> 1.1.2'   # Twitter
      }
    end

    ##
    # Attempts to load the specified gem (by name and version).
    # If the gem with the correct version cannot be found, it'll display a message
    # to the user with instructions on how to install the required gem
    def self.load(name)
      begin
        gem(name, Backup::Dependency.all[name.to_s])
        require(name.gsub('-','/'))
      rescue LoadError
        Backup::Logger.error("Dependency missing. Please install #{name} version #{Backup::Dependency.all[name.to_s]}.")
        puts "\n\s\sgem install #{name} -v '#{Backup::Dependency.all[name.to_s]}'"
        exit
      end
    end

  end
end
