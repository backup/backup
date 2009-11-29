class BackupFilesGenerator < Rails::Generator::Base

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
      m.directory "lib/tasks/backup/files"
      m.directory "lib/tasks/backup/setup"
      m.file      "backup.rake",      "lib/tasks/backup/backup.rake"
      m.file      "capistrano.rake",  "lib/tasks/backup/setup/capistrano.rake"
      m.file      "backup.sqlite3",   "lib/tasks/backup/files/backup.sqlite3"
      
      # Generates the configuration file
      m.directory "config"
      m.file      "backup.rb",        "config/backup.rb"
      
      # Generates the backup.sqlite3 database
      m.directory "db"
      m.file      "backup.sqlite3",   "db/backup.sqlite3"
      
    end
  end
  
end