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
      m.directory "lib/tasks/backup"
      m.file      "tasks/backup.rake",        "lib/tasks/backup/backup.rake"

      # Generates the configuration file
      m.directory "config"
      m.file      "config/backup.rb",         "config/backup.rb"
      
      # Generates the database migration file
      m.migration_template                    "migrations/create_backup_tables.rb",
                                              "db/migrate",
                                              :migration_file_name => "create_backup_tables"
      
    end
  end
  
end