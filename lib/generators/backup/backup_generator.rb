class BackupGenerator < Rails::Generators::Base
  source_root File.expand_path('../templates', __FILE__)
  
  def copy_files
    copy_file 'backup.rake',              'lib/tasks/backup.rake'
    copy_file 'backup.rb',                'config/backup.rb'
    
    unless Dir["#{Rails.root}/db/migrate/*create_backup_tables.rb"].any?
      copy_file 'create_backup_tables.rb',  "db/migrate/#{Time.now.utc.strftime("%Y%m%d%H%M%S")}_create_backup_tables.rb"
    end
    
    puts message
  end
  
  def message
<<-MESSAGE


  ==============================================================
  Backup's files have been generated!
  ==============================================================
  
  1: Migrate the database!
  
    rake db:migrate
  
  
  2: Set up some "Backup Settings" inside the backup configuration file!
  
    config/backup.rb
  
  
  3: Run the backups! Enjoy.
  
    rake backup:run trigger="your-specified-trigger"
  
  
  For More Information:
  http://github.com/meskyanichi/backup
  
  ==============================================================


MESSAGE
  end
  
end
