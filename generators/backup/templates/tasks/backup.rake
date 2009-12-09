namespace :backup do

  desc "Run Backup Procedure."
  task :run => :environment do
    puts "Running: #{ENV['trigger']}."
    Backup::Setup.new(ENV['trigger'], @backup_procedures).initialize_adapter
  end
  
  desc "Finds backup records by trigger"
  task :find => :environment do
    puts "Finding backup records with trigger: #{ENV['trigger']}."
    backup = Backup::Setup.new(ENV['trigger'], @backup_procedures)
    records = Array.new
    case backup.procedure.storage_name.to_sym
      when :s3    then records = Backup::Record::S3.all   :conditions => {:trigger => ENV['trigger']}
      when :scp   then records = Backup::Record::SCP.all  :conditions => {:trigger => ENV['trigger']}
      when :ftp   then records = Backup::Record::FTP.all  :conditions => {:trigger => ENV['trigger']}
      when :sftp  then records = Backup::Record::SFTP.all :conditions => {:trigger => ENV['trigger']}
    end
    
    if ENV['table'].eql?("true")
      puts Hirb::Helpers::AutoTable.render(records)
    else
      records.each do |record|
        puts record.to_yaml
      end
    end
  end
  
  desc "Truncates all records for the specified \"trigger\", excluding the physical files on s3 or the remote server."
  task :truncate => :environment do
    puts "Truncating backup records with trigger: #{ENV['trigger']}."
    Backup::Record::S3.destroy_all    :trigger => ENV['trigger'], :storage => 's3'
    Backup::Record::SCP.destroy_all   :trigger => ENV['trigger'], :storage => 'scp'
    Backup::Record::FTP.destroy_all   :trigger => ENV['trigger'], :storage => 'ftp'
    Backup::Record::SFTP.destroy_all  :trigger => ENV['trigger'], :storage => 'sftp'
  end
  
  desc "Truncates everything."
  task :truncate_all => :environment do
    puts "Truncating all backup records."
    Backup::Record::S3.destroy_all
    Backup::Record::SCP.destroy_all
    Backup::Record::FTP.destroy_all
    Backup::Record::SFTP.destroy_all
  end
  
  desc "Destroys all records for the specified \"trigger\", including the physical files on s3 or the remote server."
  task :destroy => :environment do
    puts "Destroying backup records with trigger: #{ENV['trigger']}."
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
    puts "Destroying all backup records."
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