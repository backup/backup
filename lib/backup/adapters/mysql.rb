module Backup
  module Adapters
    class MySQL < Backup::Adapters::Base
      
      attr_accessor :user, :password, :database, :skip_tables, :host, :port, :socket, :additional_options, :tables
      
      private

        # Dumps and Compresses the MySQL file 
        def perform
          log system_messages[:mysqldump]; log system_messages[:compressing]
          run "#{mysqldump} -u #{user} --password='#{password}' #{options} #{additional_options} #{database} #{tables_to_include} #{tables_to_skip} | gzip -f --best > #{File.join(tmp_path, compressed_file)}"
        end

        def mysqldump
          # try to determine the full path, and fall back to myqsldump if not found
          cmd = `which mysqldump`.chomp
          cmd = 'mysqldump' if cmd.empty?
          cmd
        end
        
        def performed_file_extension
          ".sql"
        end

        # Loads the initial settings
        def load_settings
          %w(user password database tables skip_tables additional_options).each do |attribute|
            send(:"#{attribute}=", procedure.get_adapter_configuration.attributes[attribute])
          end
          
          %w(host port socket).each do |attribute|
            send(:"#{attribute}=", procedure.get_adapter_configuration.get_options.attributes[attribute])
          end
        end
        
        # Returns a list of options in MySQL syntax
        def options
          options = String.new
          options += " --host='#{host}' "     unless host.blank?
          options += " --port='#{port}' "     unless port.blank?
          options += " --socket='#{socket}' " unless socket.blank?
          options
        end
        
        # Returns a list of tables to skip in MySQL syntax
        def tables_to_skip
          return "" unless skip_tables
          [*skip_tables].map {|table| " --ignore-table='#{database}.#{table}' "}
        end
        
        # Returns a list of tables to include in MySQL syntax
        def tables_to_include
          return "" unless tables
          [*tables].join(" ")
        end
                
    end
  end
end
