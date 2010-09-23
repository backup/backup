class BackupGenerator < Rails::Generator::Base

  # This method gets initialized when the generator gets run.
  # It will receive an array of arguments inside @args
  def initialize(runtime_args, runtime_options = {})
    super
  end
  
  # Processes the file generation/templating
  # This will automatically be run after the initialize method
  def manifest
    record do |m|
      
      # Generates the Rake Tasks and Backup Database
      m.directory "lib/tasks"
      m.file      "backup.rake", "lib/tasks/backup.rake"

      # Generates the configuration file
      m.directory "config"
      m.file      "backup.rb", "config/backup.rb"
      
      # Generates the database migration file
      m.migration_template "create_backup_tables.rb",
                           "db/migrate",
                           :migration_file_name => "create_backup_tables"
      
      # Outputs the generators message to the terminal
      puts message
    end
  end
  
  def message
    <<-MESSAGE
    
    
    ==============================================================
    Backup's files have been generated!
    ==============================================================
    
    1: Add the "Backup" gem to the config/environment.rb file!
    
      config.gem "backup"
    
    
    2: Migrate the database!

      rake db:migrate
    
    
    3: Set up some "Backup Settings" inside the backup configuration file!

      config/backup.rb
      
    
    4: Run the backups! Enjoy.
    
      rake backup:run trigger="your-specified-trigger"
      
    
    For More Information:
    http://github.com/meskyanichi/backup
    
    ==============================================================
    
    
    MESSAGE
  end
  
end