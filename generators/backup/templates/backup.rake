namespace :backup do
  
  task :boot => :environment do
    Backup::System.boot!
  end
  
  desc "Run Backup Procedure."
  task :run => :boot do
    puts "Running: #{ENV['trigger']}."
    Backup::Setup.new(ENV['trigger'], @backup_procedures).initialize_adapter
  end
  
  desc "Finds backup records by trigger"
  task :find => :boot do
    puts "Finding backup records with trigger: #{ENV['trigger']}."
    backup = Backup::Setup.new(ENV['trigger'], @backup_procedures)
    records = backup.procedure.record_class.all( :conditions => {:trigger => ENV['trigger']} )
    
    if ENV['table'].eql?("true")
      puts Hirb::Helpers::AutoTable.render(records)
    else
      records.each do |record|
        puts record.to_yaml
      end
    end
  end
  
  desc "Truncates all records for the specified \"trigger\", excluding the physical files on s3 or the remote server."
  task :truncate => :boot do
    puts "Truncating backup records with trigger: #{ENV['trigger']}."
    Backup::Record::Base.destroy_all :trigger => ENV['trigger']
  end
  
  desc "Truncates everything."
  task :truncate_all => :boot do
    puts "Truncating all backup records."
    Backup::Record::Base.destroy_all
  end
  
  desc "Destroys all records for the specified \"trigger\", including the physical files on s3 or the remote server."
  task :destroy => :boot do
    puts "Destroying backup records with trigger: #{ENV['trigger']}."
    backup = Backup::Setup.new(ENV['trigger'], @backup_procedures)
    backup.procedure.record_class.destroy_all_backups( backup.procedure, ENV['trigger'] )
  end
  
  desc "Destroys all records for the specified \"trigger\", including the physical files on s3 or the remote server."
  task :destroy_all => :boot do
    puts "Destroying all backup records."
    backup = Backup::Setup.new(false, @backup_procedures)
    backup.procedures.each do |backup_procedure|
      backup_procedure.record_class.destroy_all_backups( backup_procedure, backup_procedure.trigger )
    end
  end
  
end
