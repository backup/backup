namespace :backup do
  namespace :db do
    namespace :truncate do

      desc 'Truncates all the Backup database records; Physical files WILL NOT be deleted.'
      task :all => :environment do
        puts "Truncating All!"
        Backup::BackupRecord::S3.destroy_all
        Backup::BackupRecord::SSH.destroy_all
      end
      
      desc 'Truncates the S3 Backup database records; Physical files WILL NOT be deleted from S3.'
      task :s3 => :environment do
        puts "Truncating S3 Backup database records!"
        Backup::BackupRecord::S3.destroy_all
      end
      
      desc 'Truncates the SHH database records; Physical files WILL NOT be deleted from remote server.'
      task :ssh => :environment do
        puts "Truncating SSH database records!"
        Backup::BackupRecord::SSH.destroy_all
      end
      
    end

=begin
    namespace :destroy do
      
      desc 'Destroys all Backup database records; Physical files WILL be deleted as well.'
      task :all => :environment do
        Backup::BackupRecord::S3.destroy_all_backups
        Backup::BackupRecord::SSH.destroy_all_backups
      end
      
      desc 'Destroys S3 Backup database records; Physical files WILL be deleted as well.'
      task :s3 => :s3_config do
        Backup::BackupRecord::S3.destroy_all_backups
      end
      
      desc 'Destroys SSH Backup database records; Physical files WILL be deleted as well.'
      task :ssh => :ssh_config do
        Backup::BackupRecord::SSH.destroy_all_backups
      end
      
    end
=end

  end
end