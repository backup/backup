
# Backup Configuration File
# 
# Use the "backup" method to add another backup setting to the configuration file.
# The argument before the "do" in (backup "argument" do) is called the "trigger".
# This acts as the identifier for the configuration.
#
# In the example below we have a "mysql-backup-s3" trigger for the configuration
# inside that block. To initialize the backup process, you invoke it with the following rake task:
#
#   rake backup:run trigger="mysql-backup-s3"
# 
# You can add as many backup block settings as you want, just be sure every trigger is unique and you can run
# each of them separately.
# 
# For more information on "Backup", please refer to the wiki on github
#   http://wiki.github.com/meskyanichi/backup/configuration-file


# Initialize with:
#   rake backup:run trigger='mysql-backup-s3'
backup 'mysql-backup-s3' do
  
  adapter :mysql do
    user      'user'
    password  'password'
    database  'database'
  end
  
  storage :s3 do
    access_key_id     'access_key_id'
    secret_access_key 'secret_access_key'
    bucket            '/bucket/backups/mysql/'
  end
  
  keep_backups 25
  encrypt_with_password 'password'
  
end


# Initialize with:
#   rake backup:run trigger='mysql-backup-s3'
backup 'archive-backup-scp' do
  
  adapter :archive do
    files ["#{RAILS_ROOT}/log", "#{RAILS_ROOT}/public/assets"]
  end
  
  storage :scp do
    ip        'example.com'
    user      'user'
    password  'password'
    path      '/var/backups/archive/'
  end

  keep_backups :all
  encrypt_with_password false
  
end
