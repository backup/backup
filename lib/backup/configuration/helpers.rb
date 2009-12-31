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
      def mail_notification(&block)
        mail = Backup::Configuration::Mail.new
        mail.instance_eval &block
        @mail = mail
      end
      
    end
  end
end