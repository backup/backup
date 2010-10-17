# Backup Configuration File
# 
# Use the "backup" block to add backup settings to the configuration file.
# The argument before the "do" in (backup "argument" do) is called a "trigger".
# This acts as the identifier for the configuration.
#
# In the example below we have a "mysql-backup-s3" trigger for the backup setting.
# All the configuration is done inside this block. To initialize the backup process for this block,
# you invoke it using the following rake task:
#
#   rake backup:run trigger="mysql-backup-s3"
# 
# You can add as many backup block settings as you want, just be sure every trigger is unique and you can run
# each of them separately.
# 
# ADAPTERS
#  - MySQL
#  - PostgreSQL
#  - SQLite
#  - Archive
#  - Custom
#
# STORAGE METHODS
#  - S3      (Amazon)
#  - CF      (Rackspace Cloud Files)
#  - Dropbox (Dropbox Web Service)
#  - SCP     (Remote Server)
#  - FTP     (Remote Server)
#  - SFTP    (Remote Server)
#  - LOCAL   (Local Server)
#
# GLOBAL OPTIONS
#  - Keep Backups (keep_backups)
#  - Encrypt With Pasword (encrypt_with_password)
#  - Encrypt With GPG Public Key (encrypt_with_gpg_public_key)
#  - Notify (notify)
#
#  This is the "decrypt" command for all encrypted backups:
#    sudo backup --decrypt /path/to/encrypted/file
#
# Each Backup Setting can contain:
# - 1 Adapter
# - 1 Storage Method
# - Multiple Global Options
#
# The combination of these, however, do not matter! So experiment with it.
# 
# You can also let Backup notify you by email on successfully created backups.
# - Just uncomment the block of code below (notifier_settings) and fill in your credentials.
# - Then for set "notify" to "true" in each (backup) block you wish to be notified of.
# 
# For more information on "Backup", please refer to the wiki on github
#   http://wiki.github.com/meskyanichi/backup/configuration-file


# Notifier
#   Uncomment this if you want to enable notification by email on successful backup runs
#   You will also have to set "notify true" inside each backup block below to enable it for that particular backup
# notifier_settings do
#   
#   to    "example1@gmail.com"
#   from  "example2@gmail.com"
#   
#   smtp do
#     host            "smtp.gmail.com"
#     port            "587"
#     username        "example1@gmail.com"
#     password        "example1password"
#     authentication  "plain"
#     domain          "localhost.localdomain"
#     tls             true
#   end
# 
# end


# Initialize with:
#   rake backup:run trigger='mysql-backup-s3'
backup 'mysql-backup-s3' do
  
  adapter :mysql do
    user        'user'
    password    'password'
    database    'database'
  
    # skip_tables ['table1', 'table2', 'table3']
    # 
    # options do
    #   host    '123.45.678.90'
    #   port    '80'
    #   socket  '/tmp/socket.sock'
    # end
    # additional_options '--single-transaction  --quick'
  end
  
  storage :s3 do
    access_key_id     'access_key_id'
    secret_access_key 'secret_access_key'
    bucket            '/bucket/backups/mysql/'
    use_ssl           true
  end
  
  keep_backups 25
  encrypt_with_password 'password'
  notify false
  
end

# Initialize with:
#   rake backup:run trigger='mysql-backup-cloudfiles'
backup 'mysql-backup-cloudfiles' do

  adapter :mysql do
    user        'user'
    password    'password'
    database    'database'
  end

  storage :cloudfiles do
    username  'username'
    api_key   'api_key'
    container 'mysql_backup'
  end
  
  encrypt_with_gpg_public_key <<-KEY
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1.4.7 (Darwin)

Your very long public key goes here
-----END PGP PUBLIC KEY BLOCK-----
KEY

end

# Initialize with:
#   rake backup:run trigger='postgresql-backup-s3'
backup 'postgresql-backup-scp' do
  
  adapter :postgresql do
    user      'user'
    database  'database'

    # skip_tables ['table1', 'table2', 'table3']
  
    # options do
    #   host    '123.45.678.90'
    #   port    '80'
    #   socket  '/tmp/socket.sock'
    # end
    # additional_options '--clean --blobs'
  end
  
  storage :scp do
    ip        'example.com'
    user      'user'
    password  'password'
    path      '/var/backups/postgresql/'
  end

  keep_backups :all
  encrypt_with_password false
  notify false

end


# Initialize with:
#   rake backup:run trigger='archive-backup-ftp'
backup 'archive-backup-ftp' do
  
  adapter :archive do
    files ["#{RAILS_ROOT}/log", "#{RAILS_ROOT}/db"]
  end
  
  storage :ftp do
    ip        'example.com'
    user      'user'
    password  'password'
    path      '/var/backups/archive/'
  end

  keep_backups 10
  encrypt_with_password false
  notify false

end


# Initialize with:
#   rake backup:run trigger='custom-backup-sftp'
backup 'custom-backup-sftp' do
  
  adapter :custom do
    commands \
      [ "mysqldump            [options] [database] > :tmp_path/my_mysql_dump.sql",
        "pg_dump              [options] [database] > :tmp_path/my_postgresql_dump.sql",
        "any_other_db_format  [options] [database] > :tmp_path/my_any_other_db_format.sql" ]
  end
  
  storage :sftp do
    ip        'example.com'
    user      'user'
    password  'password'
    path      '/var/backups/custom/'
  end

  keep_backups :all
  encrypt_with_password 'password'
  notify false
  
end


# Initializ with:
#   rake backup:run trigger='sqlite-backup-local'
backup 'sqlite-backup-local' do
  
  adapter :sqlite do
    database "#{RAILS_ROOT}/db/production.sqlite3"
  end
  
  storage :local do
    path "/path/to/storage/location/"
  end
  
  keep_backups :all
  encrypt_with_password false
  notify false
  
end


# Initialize with
# rake backup:run trigger='postgresql-backup-dropbox'
backup 'postgresql-backup-dropbox' do
  
  adapter :postgresql do
    user      'devmen'
    database  'domowoi_test'
  end
  
  storage :dropbox do
    api_key           'your_api_key'
    secret_access_key 'your_api_secret'
    username          'user@example.org'
    password          'super_s3cret'
    path              'backups'
  end

  keep_backups :all
  encrypt_with_password false
  notify false
end
