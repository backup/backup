module Backup
  module Adapters
    class MongoDB < Backup::Adapters::Base
      require 'json'
      
      attr_accessor :user, :password, :database, :collections, :host, :port, :additional_options, :backup_method
      
      private
      
        BACKUP_METHOD_OPTIONS = [:mongodump, :disk_copy]

        # Dumps and Compresses the Mongodump file 
        def perform
          tmp_mongo_dir = "mongodump-#{Time.now.strftime("%Y%m%d%H%M%S")}"
          tmp_dump_dir = File.join(tmp_path, tmp_mongo_dir)

          case self.backup_method.to_sym
          when :mongodump
            log system_messages[:mongo_dump]
            run "#{mongodump} #{mongodump_options} #{collections_to_include} -o #{tmp_dump_dir} #{additional_options} > /dev/null 2>&1"
          when :disk_copy
            log system_messages[:mongo_copy]
            begin
              cmd = "#{mongo} #{mongo_disk_copy_options} --quiet --eval 'db.runCommand({fsync : 1, lock : 1}); printjson(db.runCommand({getCmdLineOpts:1}));' admin"
              output = JSON.parse(`#{cmd}`)

              #lets go find the dbpath.  it is either going to be in the argv just returned OR we are going to have to parse through the mongo config file
              cmd = "mongo --quiet --eval 'printjson(db.runCommand({getCmdLineOpts:1}));' admin"
              output = JSON.parse(`#{cmd}`)
              db_path = output['argv'][output['argv'].index('--dbpath') + 1] if output['argv'].index('--dbpath')            #see if --dbpath was passed in
              db_path ||= $1 if output['argv'].index('--config') && File.read(output['argv'][output['argv'].index('--config') + 1]) =~ /dbpath\s*=\s*([^\s]*)/  #see if --config is passed in, and if so, lets parse it
              db_path ||= "/data/db/" #mongo's default path
              run "cp -rp #{db_path} #{tmp_dump_dir}"              
            ensure
              #attempting to unlock
              cmd = "#{mongo} #{mongo_disk_copy_options} --quiet --eval 'printjson(db.currentOp());' admin"
              output = JSON.parse(`#{cmd}`)
              (output['fsyncLock'] || 1).to_i.times do
                `#{mongo} #{mongo_disk_copy_options} --quiet --eval 'db.$cmd.sys.unlock.findOne();' admin`                  
              end
            end
          else
            puts "you did not enter a valid backup_method option.  Your choices are: #{BACKUP_METHOD_OPTIONS.join(', ')}"
            exit 1
          end          
            
          log system_messages[:compressing]
          run "tar -cz -C #{tmp_path} -f #{File.join(tmp_path, compressed_file)} #{tmp_mongo_dir}"
        end

        def mongodump
          cmd = `which mongodump`.chomp
          cmd = 'mongodump' if cmd.empty?
          cmd
        end
        
        def mongo
          cmd = `which mongo`.chomp
          cmd = 'mongo' if cmd.empty?
          cmd          
        end
        
        def performed_file_extension
          ".tar"
        end

        # Loads the initial settings
        def load_settings
          %w(user password database collections additional_options backup_method).each do |attribute|
            send(:"#{attribute}=", procedure.get_adapter_configuration.attributes[attribute])
          end
          
          %w(host port).each do |attribute|
            send(:"#{attribute}=", procedure.get_adapter_configuration.get_options.attributes[attribute])
          end
          
          self.backup_method ||= :mongodump
        end
        
        # Returns a list of options in Mongodump syntax
        def mongodump_options
          options = String.new
          options += " --username='#{user}' "     unless user.blank?
          options += " --password='#{password}' " unless password.blank?
          options += " --host='#{host}' "         unless host.blank?
          options += " --port='#{port}' "         unless port.blank?
          options += " --db='#{database}' "       unless database.blank?
          options
        end
        
        def mongo_disk_copy_options
          options = String.new
          options += " --username='#{user}' "     unless user.blank?
          options += " --password='#{password}' " unless password.blank?
          options += " --host='#{host}' "         unless host.blank?
          options += " --port='#{port}' "         unless port.blank?
          options          
        end
                
        # Returns a list of collections to include in Mongodump syntax
        def collections_to_include
          return "" unless collections
          "--collection #{[*collections].join(" ")}"
        end
                
    end
  end
end
