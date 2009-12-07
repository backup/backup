module Backup
  module Environment
    module Rails
      
      if defined? RAILS_ENV
        
        # Sets BACKUP_PATH equal to RAILS_ROOT
        BACKUP_PATH = RAILS_ROOT
      
        # Sets DB_CONNECTION_SETTINGS to false
        DB_CONNECTION_SETTINGS = false
    
      end
    
    end
  end
end