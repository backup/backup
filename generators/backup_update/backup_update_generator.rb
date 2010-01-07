class BackupUpdateGenerator < Rails::Generator::Base

  # This method gets initialized when the generator gets run.
  # It will receive an array of arguments inside @args
  def initialize(runtime_args, runtime_options = {})
    super
  end
  
  # Processes the file generation/templating
  # This will automatically be run after the initialize method
  def manifest
    record do |m|
      
      # Generates the database update migration file
      m.migration_template                    "migrations/update_backup_tables.rb",
                                              "db/migrate",
                                              :migration_file_name => "update_backup_tables"
      
      # Outputs the generators message to the terminal
      puts message
    end
  end
  
  def message
    <<-MESSAGE
    
    
    
    ==============================================================
    Backup's update files have been generated!
    ==============================================================
    
    Please follow these instructions Backup:
    
    1: Please migrate the database to finish the update!

      rake db:migrate
    
    
    For More Information:
    http://github.com/meskyanichi/backup
    
    ==============================================================
    
    
    
    MESSAGE
  end
  
end
