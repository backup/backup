class UpdateBackupTables < ActiveRecord::Migration
  def self.up
    change_table :backup do |t|
      t.rename :storage, :type # will use STI from now
      t.string :md5sum
    end
    
    ActiveRecord::Base.connection.execute "UPDATE backup SET type='Backup::Record::FTP' WHERE type='ftp'"
    ActiveRecord::Base.connection.execute "UPDATE backup SET type='Backup::Record::Local' WHERE type='local'"
    ActiveRecord::Base.connection.execute "UPDATE backup SET type='Backup::Record::S3' WHERE type='s3'"
    ActiveRecord::Base.connection.execute "UPDATE backup SET type='Backup::Record::SCP' WHERE type='scp'"
    ActiveRecord::Base.connection.execute "UPDATE backup SET type='Backup::Record::SFTP' WHERE type='sftp'"
  end

  def self.down
    ActiveRecord::Base.connection.execute "UPDATE backup SET type='ftp' WHERE type='Backup::Record::FTP'"
    ActiveRecord::Base.connection.execute "UPDATE backup SET type='local' WHERE type='Backup::Record::Local'"
    ActiveRecord::Base.connection.execute "UPDATE backup SET type='s3' WHERE type='Backup::Record::S3'"
    ActiveRecord::Base.connection.execute "UPDATE backup SET type='scp' WHERE type='Backup::Record::SCP'"
    ActiveRecord::Base.connection.execute "UPDATE backup SET type='sftp' WHERE type='Backup::Record::SFTP'"
    
    change_table :backup do |t|
      t.rename :type, :storage
      t.remove :md5sum
    end
  end
end
