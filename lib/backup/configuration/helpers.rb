module Backup
  module Configuration
    module Helpers
      
      # A helper method for the config/backup.rb configuration file
      # Expects a trigger in argument one (STRING)
      # Expects a block of settings
      def backup(trigger, &block)
        backup = Backup::Configuration::Base.new(trigger)
        backup.instance_eval &block
        @backup_procedures ||= Array.new
        @backup_procedures << backup
      end
      
    end
  end
end