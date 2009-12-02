module Backup
  module Configuration
    module Helpers
      
      def backup(trigger, &block)
        backup = Backup::Configuration::Base.new(trigger)
        backup.instance_eval &block
        @backup_procedures ||= Array.new
        @backup_procedures << backup
      end
      
    end
  end
end