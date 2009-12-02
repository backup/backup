# Load in Connectivity and Transfer Gems
require 'net/ssh'
require 'net/scp'
require 'net/ftp'
require 'net/sftp'
require 'aws/s3'

# Load in Adapters
require 'backup/adapters/base'
require 'backup/adapters/mysql'
require 'backup/adapters/postgresql'
require 'backup/adapters/archive'
require 'backup/adapters/custom'

# Load in Connectors
require 'backup/connection/s3'

# Load in Storage
require 'backup/storage/s3'
require 'backup/storage/scp'
require 'backup/storage/ftp'
require 'backup/storage/sftp'

# Load in Backup Recorders
require 'backup/record/s3'
require 'backup/record/scp'
require 'backup/record/ftp'
require 'backup/record/sftp'

# Load in Configuration
require 'backup/configuration/base'
require 'backup/configuration/adapter'
require 'backup/configuration/adapter_options'
require 'backup/configuration/storage'
require 'backup/configuration/helpers'

# Load Backup Configuration Helpers
include Backup::Configuration::Helpers

# Load in User Configured Backup Procedures if the file exists
if File.exist?(File.join(RAILS_ROOT, 'config', 'backup.rb'))
  require File.join(RAILS_ROOT, 'config', 'backup.rb')
end

# Backup Module
module Backup
  class Setup
  
    attr_accessor :trigger, :procedures, :procedure
  
    def initialize(trigger, procedures)
      self.trigger    = trigger
      self.procedures = procedures
      self.procedure  = find_triggered_procedure unless trigger.eql?(false)
    end
    
    def initialize_adapter
      case procedure.adapter_name.to_sym
        when :mysql       then Backup::Adapters::MySQL.new(trigger, procedure)
        when :postgresql  then Backup::Adapters::PostgreSQL.new(trigger, procedure)
        when :archive     then Backup::Adapters::Archive.new(trigger, procedure)
        when :custom      then Backup::Adapters::Custom.new(trigger, procedure)
        else raise "Unknown Adapter: \"#{procedure.adapter_name}\""
      end
    end
    
    def find_triggered_procedure
      procedures.each do |procedure|
        if procedure.trigger.eql?(trigger)
          return procedure
        end
      end
      available_triggers = procedures.each.map {|procedure| "- #{procedure.trigger}\n" }
      raise "Could not find a backup procedure with the trigger \"#{trigger}\". \nHere's a list of available triggers:\n#{available_triggers}"
    end

  end
end