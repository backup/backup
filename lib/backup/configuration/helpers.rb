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
      
      # A helper method for the config/mail.rb configuration file
      # Takes a block containing the mail options
      def notifier_settings(&block)
        @mail_configuration = Backup::Configuration::Mail.new
        @mail_configuration.instance_eval &block
      end
      
    end
  end
end