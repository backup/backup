namespace :backup do

  desc "Run Backup Procedure."
  task :run => :environment do
    Backup::Setup.new(ENV['trigger'], @backup_procedures).initialize_adapter
  end
  
  desc "Truncates all records for the specified \"trigger\", excluding the physical files on s3 or the remote server."
  task :truncate => :environment do
    backup = Backup::Setup.new(ENV['trigger'], @backup_procedures)
    case backup.procedure.storage_name.to_sym
      when :s3    then Backup::Record::S3.destroy_all   :trigger => ENV['trigger'], :storage => 's3'
      when :scp   then Backup::Record::SCP.destroy_all  :trigger => ENV['trigger'], :storage => 'scp'
      when :ftp   then Backup::Record::FTP.destroy_all  :trigger => ENV['trigger'], :storage => 'ftp'
      when :sftp  then Backup::Record::SFTP.destroy_all :trigger => ENV['trigger'], :storage => 'sftp'
    end
  end
  
  desc "Truncates everything."
  task :truncate_all => :environment do
    Backup::Record::S3.destroy_all
    Backup::Record::SCP.destroy_all
    Backup::Record::FTP.destroy_all
    Backup::Record::SFTP.destroy_all
  end
  
  desc "Destroys all records for the specified \"trigger\", including the physical files on s3 or the remote server."
  task :destroy => :environment do
    backup = Backup::Setup.new(ENV['trigger'], @backup_procedures)
    case backup.procedure.storage_name.to_sym
      when :s3    then Backup::Record::S3.destroy_all_backups   backup.procedure,  ENV['trigger']
      when :scp   then Backup::Record::SCP.destroy_all_backups  backup.procedure,  ENV['trigger']
      when :ftp   then Backup::Record::FTP.destroy_all_backups  backup.procedure,  ENV['trigger']
      when :sftp  then Backup::Record::SFTP.destroy_all_backups backup.procedure,  ENV['trigger']
    end
  end
  
  desc "Destroys all records for the specified \"trigger\", including the physical files on s3 or the remote server."
  task :destroy_all => :environment do
    backup = Backup::Setup.new(false, @backup_procedures)
    backup.procedures.each do |backup_procedure|
      case backup_procedure.storage_name.to_sym
        when :s3    then Backup::Record::S3.destroy_all_backups     backup_procedure,  backup_procedure.trigger
        when :scp   then Backup::Record::SCP.destroy_all_backups    backup_procedure,  backup_procedure.trigger
        when :ftp   then Backup::Record::FTP.destroy_all_backups    backup_procedure,  backup_procedure.trigger
        when :sftp  then Backup::Record::SFTP.destroy_all_backups   backup_procedure,  backup_procedure.trigger
      end
    end
  end
  
end