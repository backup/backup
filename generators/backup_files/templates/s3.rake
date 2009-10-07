namespace :backup do
  namespace :s3 do
    
    # => rake backup:s3:mysql
    # Fill in your mysql credentials to allow Backup to create a mysql dump, and which database to make a dump from.
    # Specify that you want to use :s3
    # Fill in your Amazon S3 Account's Credentials (access_key_id, secret_access_key)
    # Specify which bucket you wish to store your files to.
    # If you wish to put specific files in subfolders inside the bucket, you may do so by doing something like this:
    # :bucket => "my_bucket/subfolder1/subfolder2" etc.
    desc 'Makes a backup from a MySQL database and transfers it to Amazon S3.'
    task :mysql => :s3_config do
      @config = @config['mysql']
      Backup::Adapter::Mysql.new({
        :adapter    => 'mysql',
        :mysql => {
          :user     => @config['mysql_config']['user'],
          :password => @config['mysql_config']['password'],
          :database => @config['mysql_config']['database']
        },
        
        :encrypt      => @config['encrypt'],
        :keep_backups => @config['keep_backups'],
        
        :use => :s3,
        :s3 => {
          :access_key_id      => @config['s3']['access_key_id'],
          :secret_access_key  => @config['s3']['secret_access_key'],
          :bucket             => @config['s3']['bucket']
        }
      }).run
    end
    
    # => rake backup:s3:sqlite3
    # Specify which sqlite3 file you wish to back up. This will generally be "production.sqlite3". (and this is the default, so you can remove the :file attribute if it is)
    # Specify that you want to use :s3
    # Fill in your Amazon S3 Account's Credentials (access_key_id, secret_access_key)
    # Specify which bucket you wish to store your files to.
    # If you wish to put specific files in subfolders inside the bucket, you may do so by doing something like this:
    # :bucket => "my_bucket/subfolder1/subfolder2" etc.
    desc 'Makes a backup from a SQLite3 database and transfers it to Amazon S3.'
    task :sqlite3 => :s3_config do
      @config = @config['sqlite3']
      Backup::Adapter::Sqlite3.new({
        :adapter      => 'sqlite3',
        :file         => @config['file'],
        :path         => @config['path'],
        :encrypt      => @config['encrypt'],
        :keep_backups => @config['keep_backups'],
        
        :use => :s3,
        :s3 => {
          :access_key_id      => @config['s3']['access_key_id'],
          :secret_access_key  => @config['s3']['secret_access_key'],
          :bucket             => @config['s3']['bucket']
        }
      }).run
    end
    
    # => rake backup:s3:assets
    # Specify which directory (:path) (and all it's underlaying files and folders) you wish to backup.
    # Specify that you want to use :s3
    # Fill in your Amazon S3 Account's Credentials (access_key_id, secret_access_key)
    # Specify which bucket you wish to store your files to.
    # If you wish to put specific files in subfolders inside the bucket, you may do so by doing something like this:
    # :bucket => "my_bucket/subfolder1/subfolder2" etc.
    desc 'Makes a backup from Assets and transfers it to Amazon S3.'
    task :assets => :s3_config do
      @config = @config['assets']
      Backup::Adapter::Assets.new({
        :adapter      => 'assets',
        :path         => @config['path'],
        :encrypt      => @config['encrypt'],
        :keep_backups => @config['keep_backups'],
        
        :use => :s3,
        :s3 => {
          :access_key_id      => @config['s3']['access_key_id'],
          :secret_access_key  => @config['s3']['secret_access_key'],
          :bucket             => @config['s3']['bucket']
        }
      }).run
    end
    
    # => rake backup:s3:custom
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
    # By default, after the backup has been pushed to S3, it will remove the original files (created from your :command attribute)
    # If you wish to keep these files, then add the following line:
    #  :keep_original_files => true
    # This is set to 'false' by default, as you most likely don't want to keep these files on your production server.
    # 
    # Just use the ":use => :s3" as usual to tell it you would like to back up these files using S3.
    # And then, like in the example below, provide the S3 credentials/details to be able to connect to the server you wish to back these files up to.
    desc 'Makes a backup from a Custom database and transfers it to Amazon S3.'
    task :custom => :s3_config do
      @config = @config['custom']
      Backup::Adapter::Custom.new({
        :adapter      => 'custom',
        :file         => @config['file'],
        :path         => @config['path'],
        :command      => @config['command'],
        :encrypt      => @config['encrypt'],
        :keep_backups => @config['keep_backups'],
                
        :use => :s3,
        :s3 => { 
          :access_key_id      => @config['s3']['access_key_id'],
          :secret_access_key  => @config['s3']['secret_access_key'],
          :bucket             => @config['s3']['bucket']
        }
      }).run
    end
  end
end