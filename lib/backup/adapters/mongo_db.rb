module Backup
  module Adapters
    class MongoDB < Backup::Adapters::Base
      
      attr_accessor :user, :password, :database, :collections, :host, :port, :additional_options
      
      private

        # Dumps and Compresses the Mongodump file 
        def perform
          log system_messages[:mongodump]
          tmp_mongo_dir = "mongodump-#{Time.now.strftime("%Y%m%d%H%M%S")}"
          tmp_dump_dir = File.join(tmp_path, tmp_mongo_dir)
          run "#{mongodump} #{options} #{collections_to_include} -o #{tmp_dump_dir} #{additional_options} > /dev/null 2>&1"

          log system_messages[:compressing]
          run "tar -cz -C #{tmp_path} -f #{File.join(tmp_path, compressed_file)} #{tmp_mongo_dir}"
        end

        def mongodump
          # try to determine the full path, and fall back to myqsldump if not found
          cmd = `which mongodump`.chomp
          cmd = 'mongodump' if cmd.empty?
          cmd
        end
        
        def performed_file_extension
          ".bson.tar"
        end

        # Loads the initial settings
        def load_settings
          %w(user password database collections additional_options).each do |attribute|
            send(:"#{attribute}=", procedure.get_adapter_configuration.attributes[attribute])
          end
          
          %w(host port).each do |attribute|
            send(:"#{attribute}=", procedure.get_adapter_configuration.get_options.attributes[attribute])
          end
        end
        
        # Returns a list of options in Mongodump syntax
        def options
          options = String.new
          options += " --username='#{user}' "     unless user.blank?
          options += " --password='#{password}' " unless password.blank?
          options += " --host='#{host}' "         unless host.blank?
          options += " --port='#{port}' "         unless port.blank?
          options += " --db='#{database}' "       unless database.blank?
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
