module Backup
  module Environment
    module UnixConfiguration
      
      require 'active_record'
      
      # Sets BACKUP_PATH
      BACKUP_PATH = ENV['BACKUP_PATH'] || "/opt/backup"
      
      # Sets DB_CONNECTION_SETTINGS
      DB_CONNECTION_SETTINGS = {
        :adapter  => "sqlite3",
        :database => "#{BACKUP_PATH}/backup.sqlite3",
        :pool     => 5,
        :timeout  => 5000 
      }

      module Commands
        
        def setup
          unless File.directory?(BACKUP_PATH)
            puts "Installing Backup in #{BACKUP_PATH}.."
            %x{ #{sudo} mkdir -p #{File.join(BACKUP_PATH, 'config')} }
            %x{ #{sudo} cp #{File.join(File.dirname(__FILE__), '..', '..', '..', 'setup', 'backup.sqlite3')} #{BACKUP_PATH} }
            %x{ #{sudo} cp #{File.join(File.dirname(__FILE__), '..', '..', '..', 'setup', 'backup.rb')} #{File.join(BACKUP_PATH, 'config')} }
            puts <<-MESSAGE
              
  ==============================================================
  Backup has been set up!
  ==============================================================

  1: Set up some "Backup Settings" inside the configuration file!

    #{BACKUP_PATH}/config/backup.rb


  2: Run the backups!

    sudo backup --run [trigger]


  For a list of Backup commands:

    sudo backup --help
  

  For More Information:

    http://github.com/meskyanichi/backup

  ==============================================================
              
            MESSAGE
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
          %x{ #{sudo} rm -rf #{BACKUP_PATH} }
        end
      end
      
      module Helpers

        def confirm_configuration_file_existence
          unless File.exist?(File.join(BACKUP_PATH, 'config', 'backup.rb'))
            puts "\nBackup could not find the Backup Configuration File."
            puts "Did you set up Backup? Do so if you haven't yet:"
            puts "\nbackup --setup\n "
            exit
          end
        end

        def sudo
          if writable?(BACKUP_PATH)
            ""
          else
            "sudo"
          end
        end

        private
        def writable?(f)
          unless File.exists?(f)
            writable?(File.dirname(f))
          else
            File.writable?(f)
          end
        end
      end
    
    end
  end
end
