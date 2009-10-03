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
          :ip   => "mydomain.com", # or: 123.45.678.90
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
          :ip   => "mydomain.com", # or: 123.45.678.90
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
          :ip   => "mydomain.com", # or: 123.45.678.90
          :path => "/var/backups/etc"
        }
      }).run
    end
    
    # => rake backup:ssh:custom
    # This is a more complex implementation of the Backup gem.
    # Might you be using a database type that is currently not supported, then you can manually create an SQL dump
    # using the :command attribute. This will take either a single string, or an array of strings, depending on how many
    # commands you wish to execute.
    # 
    # Single Command
    #  :command => "my command"
    # Multiple Commands
    #  :command => ["my command 1", "my command 2", "my command 3"] etc.
    #
    # This means you have full control over where the sql dump should be placed. But, depending on your decision, you must
    # set the correct path to the file(s) (sql dumps) that have been generated.
    # 
    # Path To File(s) Directory
    #  :path => "#{RAILS_ROOT}/db"
    #  
    # Finally, you must specify which file(s) should be backed up.
    # The :file attribute can take either a single string, or an array of strings to add multiple files.
    # 
    # Select a single file to backup from the :path directory you specified
    #  :file => "foobar1.sql"
    # Select multiple files to backup from the :path directory you specified
    #  :file => ["foobar1.sql", "foobar2.sql"] etc
    # 
    # When you specify you would like to backup multiple files, it will automatically archive these as a "tar" for you and then compress it.  
    #
    # By default, after the backup has been pushed to your backup server using SSH, it will remove the original files (created from your :command attribute)
    # If you wish to keep these files, then add the following line:
    #  :keep_original_files => true
    # This is set to 'false' by default, as you most likely don't want to keep these files on your production server.
    #
    # Just use the ":use => :ssh" as usual to tell it you would like to back up these files using SSH.
    # And then, like in the example below, provide the SSH details to be able to connect to the server you wish to back these files up to.
    task :custom => :environment do
      Backup::Custom.new({
        :command  => ["mysqldump --quick -u root --password='' foobar > #{RAILS_ROOT}/db/foobar1.sql",
                      "mysqldump --quick -u root --password='' foobar > #{RAILS_ROOT}/db/foobar2.sql"],
                      
        :path     => "#{RAILS_ROOT}/db",
        :file     => ["foobar1.sql", "foobar2.sql"],
                
        :use => :ssh,
        :ssh => { 
          :user => "root",
          :ip   => "mydomain.com", # or: 123.45.678.90
          :path => "/var/backups/etc"
        }
      }).run
    end
  end
end