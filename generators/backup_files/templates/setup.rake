namespace :backup do
  namespace :setup do
    desc "Automatically sets up Capistrano Structure for you!"
    task :capistrano => :environment do
      puts 'Looking for shared path!'
      if File.directory?("../../shared") then
        puts 'Found shared path!'
        puts 'Looking for db folder in shared path!'
      	unless File.directory?("../../shared/db") then
          puts 'Cound not find db folder in shared path! Creating it now!'
      		%x{ mkdir -p ../../shared/db }
      	else
      	  puts 'Found db folder in shared path!'
      	end
	      
	      puts 'Looking for backup.sqlite3 in shared/db path!'
	      unless File.exist?("../../shared/db/backup.sqlite3") then
	        puts 'Could not find, creating it now!'
	        %x{ cp #{RAILS_ROOT}/lib/tasks/backup/files/backup.sqlite3 ../../shared/db/backup.sqlite3 }
        else
          puts "backup.sqlite3 already exists in the shared/db folder! Skipping backup.sqlite3 creation!"
        end
	        %x{ ln -nfs #{RAILS_ROOT}/../../shared/db/backup.sqlite3 #{RAILS_ROOT}/db/backup.sqlite3 }
	        puts "Set up a symbolic link to the backup.sqlite3 inside #{RAILS_ROOT}/db/ folder!"
      end
    end
  end
end