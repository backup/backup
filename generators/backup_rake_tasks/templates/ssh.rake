namespace :backup do
  namespace :ssh do
    
    # => rake backup:ssh:mysql
    # Fill in your mysql credentials to allow Backup to create a mysql dump, and which database to make a dump from.
    # Specify that you want to use :ssh
    # Specify what user should connect through SSH, to what address (be it IP or an URL) and the absolute path on the backup-server
    # to where Backup should store the backups.
    task :mysql => :environment do
      Backup::Mysql.new({
        :mysql => {
          :user     => "",
          :password => "",
          :database => ""
        },
        
        :use => :ssh,
        :ssh => {
          :user => "root",
          :ip   => "123.45.678.90", # OR my-domain.com
          :path => "/var/backups/etc"
        }
      }).run
    end
    
    # => rake backup:ssh:sqlite3
    # Specify which sqlite3 file you wish to back up. This will generally be "production.sqlite3". (and this is the default, so you can remove the :file attribute if it is)
    # If your sqlite3 file is not located inside the #{RAILS_ROOT}/db folder, then add a :path => "#{RAILS_ROOT}/path/to/db/folder" 
    # Specify that you want to use :ssh
    # Specify what user should connect through SSH, to what address (be it IP or an URL) and the absolute path on the backup-server
    # to where Backup should store the backups.
    task :sqlite3 => :environment do
      Backup::Sqlite3.new({
        :file => 'production.sqlite3', # "production.sqlite3" is default, can remove the whole :file attribute or change it's value
        
        :use => :ssh,
        :ssh => {
          :user => "root",
          :ip   => "123.45.678.90", # OR my-domain.com
          :path => "/var/backups/etc"
        }
      }).run
    end
    
    # => rake backup:ssh:assets
    # Specify which directory (:path) (and all it's underlaying files and folders) you wish to backup.
    # Specify that you want to use :ssh
    # Specify what user should connect through SSH, to what address (be it IP or an URL) and the absolute path on the backup-server
    # to where Backup should store the backups.
    task :assets => :environment do
      Backup::Assets.new({
        :path => "#{RAILS_ROOT}/public/assets",
        
        :use => :ssh,
        :ssh => {
          :user => "root",
          :ip   => "123.45.678.90", # OR my-domain.com
          :path => "/var/backups/etc"
        }
      }).run
    end
  end
end