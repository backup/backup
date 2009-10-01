namespace :backup do
  namespace :s3 do
    
    # => rake backup:s3:mysql
    # Fill in your mysql credentials to allow Backup to create a mysql dump, and which database to make a dump from.
    # Specify that you want to use :s3
    # Fill in your Amazon S3 Account's Credentials (access_key_id, secret_access_key)
    # Specify which bucket you wish to store your files to.
    # If you wish to put specific files in subfolders inside the bucket, you may do so by doing something like this:
    # :bucket => "my_bucket/subfolder1/subfolder2" etc.
    task :mysql => :environment do
      Backup::Mysql.new({
        :mysql => {
          :user     => "",
          :password => "",
          :database => ""
        },
        
        :use => :s3,
        :s3 => {
          :access_key_id      => '',
          :secret_access_key  => '',
          :bucket             => ''
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
    task :sqlite3 => :environment do
      Backup::Sqlite3.new({
        :file => 'production.sqlite3', # "production.sqlite3" is default, can remove the whole :file attribute or change it's value
        
        :use => :s3,
        :s3 => {
          :access_key_id      => '',
          :secret_access_key  => '',
          :bucket             => ''
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
    task :assets => :environment do
      Backup::Assets.new({
        :path => "#{RAILS_ROOT}/public/assets",
        
        :use => :s3,
        :s3 => {
          :access_key_id      => '',
          :secret_access_key  => '',
          :bucket             => ''
        }
      }).run
    end
  end
end