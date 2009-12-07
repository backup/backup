module Backup
  module Environment
    module Unix
      
      require 'active_record'
      require 'optparse'
      
      # Sets BACKUP_PATH equal to /opt/backup
      BACKUP_PATH = "/opt/backup"
      
      # Sets DB_CONNECTION_SETTINGS
      DB_CONNECTION_SETTINGS = {
        :adapter  => "sqlite3",
        :database => "/opt/backup/backup.sqlite3",
        :pool     => 5,
        :timeout  => 5000 
      }

      module Commands
        def setup
          unless File.directory?(BACKUP_PATH)
            puts "Installing Backup in #{BACKUP_PATH}.."
            %x{ sudo mkdir -p #{File.join(BACKUP_PATH, 'config')} }
            %x{ sudo cp #{File.join(File.dirname(__FILE__), '..', '..', '..', 'setup', 'backup.sqlite3')} #{BACKUP_PATH} }
            %x{ sudo cp #{File.join(File.dirname(__FILE__), '..', '..', '..', 'setup', 'backup.rb')} #{File.join(BACKUP_PATH, 'config')} }
          else
            puts "\nBackup is already installed in #{BACKUP_PATH}..\n"
            puts "If you want to reset it, run:\n\nbackup --reset\n\n"
            puts "This will reinstall it."
            puts "Warning: All configuration will be lost!\n\n"
          end
        end

        def reset
          if File.directory?(BACKUP_PATH)
            remove
            setup
          else
            puts "Backup is not installed.\n"
            puts "Run the following command to install it:\n\nbackup --setup"
          end
        end

        def remove
          puts "Removing Backup..\n"
          %x{ sudo rm -rf #{BACKUP_PATH} }
        end
      end
    
    end
  end
end