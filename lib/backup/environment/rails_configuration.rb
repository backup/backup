module Backup
  module Environment
    module RailsConfiguration
      
      if defined?(Rails.root)
        # Sets BACKUP_PATH equal to Rails.root
        BACKUP_PATH = Rails.root.to_s
      
        # Sets DB_CONNECTION_SETTINGS to false
        DB_CONNECTION_SETTINGS = false
      end
    
    end
  end
end