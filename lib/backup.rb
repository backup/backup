BACKUP_SYSTEM = Proc.new do
  # Load Gems
  require 'hirb'

  # Load Extensions
  require 'backup/core_ext/object'

  # Load Environments
  require 'backup/environment/base'
  require 'backup/environment/unix_configuration'
  require 'backup/environment/rails_configuration'

  # Load Configuration
  require 'backup/configuration/attributes'
  require 'backup/configuration/base'
  require 'backup/configuration/adapter'
  require 'backup/configuration/adapter_options'
  require 'backup/configuration/storage'
  require 'backup/configuration/mail'
  require 'backup/configuration/smtp'
  require 'backup/configuration/helpers'

  require 'backup/command_helper'

  # Include the Configuration and Environment Helpers
  include Backup::Configuration::Helpers
  include Backup::Environment::Base

  # Load either UNIX or RAILS environment configuration
  case current_environment
    when :unix  then include Backup::Environment::UnixConfiguration
    when :rails then include Backup::Environment::RailsConfiguration
  end

  # Load configuration
  if File.exist?(File.join(BACKUP_PATH, 'config', 'backup.rb'))
    require File.join(BACKUP_PATH, 'config', 'backup.rb')
  end

  # Load Mail Notifier
  require 'backup/mail/base'

  # Set Mail Configuration (extracted from the backup.rb configuration file) inside the Mail Class
  Backup::Mail::Base.setup(@mail_configuration)
end

# Backup Module
module Backup
  
  class System
    def self.boot!
      BACKUP_SYSTEM.call
      true
    end
  end
  
  module Adapters
    autoload :Base,       'backup/adapters/base'
    autoload :MySQL,      'backup/adapters/mysql'
    autoload :MongoDB,     'backup/adapters/mongo_db'
    autoload :SQLite,     'backup/adapters/sqlite'
    autoload :PostgreSQL, 'backup/adapters/postgresql'
    autoload :Archive,    'backup/adapters/archive'
    autoload :Custom,     'backup/adapters/custom'
  end

  module Storage
    autoload :Base,       'backup/storage/base'
    autoload :CloudFiles, 'backup/storage/cloudfiles'
    autoload :S3,         'backup/storage/s3'
    autoload :SCP,        'backup/storage/scp'
    autoload :FTP,        'backup/storage/ftp'
    autoload :SFTP,       'backup/storage/sftp'
    autoload :Local,      'backup/storage/local'
    autoload :Dropbox,    'backup/storage/dropbox'
  end

  module Record
    autoload :Base,       'backup/record/base'
    autoload :CloudFiles, 'backup/record/cloudfiles'
    autoload :S3,         'backup/record/s3'
    autoload :SCP,        'backup/record/scp'
    autoload :FTP,        'backup/record/ftp'
    autoload :SFTP,       'backup/record/sftp'
    autoload :Local,      'backup/record/local'
    autoload :Dropbox,    'backup/record/dropbox'
  end

  class Setup
  
    attr_accessor :trigger, :procedures, :procedure
    
    # Sets the Trigger and All Available Procedures.
    # Will not find a specific procedure if the "trigger" argument is set to false.
    def initialize(trigger, procedures)
      self.trigger    = trigger
      self.procedures = procedures
      self.procedure  = find_triggered_procedure unless trigger.eql?(false)
    end
    
    # Initializes one of the few adapters and start the backup process
    def initialize_adapter
      case procedure.adapter_name.to_sym
        when :mongo       then Backup::Adapters::MongoDB.new    trigger, procedure
        when :mysql       then Backup::Adapters::MySQL.new      trigger, procedure
        when :sqlite      then Backup::Adapters::SQLite.new     trigger, procedure
        when :postgresql  then Backup::Adapters::PostgreSQL.new trigger, procedure
        when :archive     then Backup::Adapters::Archive.new    trigger, procedure
        when :custom      then Backup::Adapters::Custom.new     trigger, procedure
        else
          puts "Unknown Adapter: \"#{procedure.adapter_name}\"."
          exit
      end
    end
    
    # Scans through all the backup settings and returns the backup setting
    # that was specified in the "trigger" argument.
    # If an non-existing trigger is specified, it will raise an error and display
    # all the available triggers.
    def find_triggered_procedure
      procedures.each do |procedure|
        if procedure.trigger.eql?(trigger)
          return procedure
        end
      end
      available_triggers = procedures.map {|procedure| "- #{procedure.trigger}\n" }
      puts "Could not find a backup procedure with the trigger \"#{trigger}\". \nHere's a list of available triggers:\n#{available_triggers}"
      exit
    end

  end
end
