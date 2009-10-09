namespace :backup do
  namespace :db do
    namespace :truncate do
      
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


    namespace :destroy do
      
      desc 'Destroys S3 Backup database records; Physical files WILL be deleted as well.'
      task :s3 => :s3_config do
        puts "Removing all backups from S3.."
        @adapters.each do |adapter|
          if @config[adapter]
            unless @config[adapter].is_a?(Array)
              puts "\n\n-- Processing #{adapter} backups --"
              Backup::BackupRecord::S3.destroy_all_backups(adapter, @config[adapter], 0)
            else
              puts "\n\n-- Processing #{adapter} backups --"
              @config[adapter].each_with_index do |config, index|
                Backup::BackupRecord::S3.destroy_all_backups(adapter, config, index)  
              end
            end
          end
        end
        puts "\n\nAll S3 backups destroyed!\n\n"
      end
      
      desc 'Destroys SSH Backup database records; Physical files WILL be deleted as well.'
      task :ssh => :ssh_config do
        puts "Removing all backups from remote server through SSH.."
        @adapters.each do |adapter|
          if @config[adapter]
            unless @config[adapter].is_a?(Array)
              puts "\n\n-- Processing #{adapter} backups --"
              Backup::BackupRecord::SSH.destroy_all_backups(adapter, @config[adapter], 0)
            else
              puts "\n\n-- Processing #{adapter} backups --"
              @config[adapter].each_with_index do |config, index|
                Backup::BackupRecord::SSH.destroy_all_backups(adapter, config, index)  
              end
            end
          end
        end
        puts "\n\nAll backups from remote server destroyed!\n\n"
      end
      
    end
  end
end