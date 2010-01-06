module Backup
  module Adapters
    class MySQL < Backup::Adapters::Base
      
      attr_accessor :dumped_file, :user, :password, :database, :skip_tables, :host, :port, :socket, :additional_options
      
      private

        # Dumps and Compresses the MySQL file 
        def perform
          puts system_messages[:mysqldump]; puts system_messages[:compressing]
          %x{ mysqldump -u #{user} --password='#{password}' #{options} #{additional_options} #{database} #{tables_to_skip} | gzip -f --best > #{File.join(tmp_path, compressed_file)} }
        end
        
        # Loads the initial settings
        def load_settings
          self.trigger  = procedure.trigger
          
          %w(user password database skip_tables additional_options).each do |attribute|
            send(:"#{attribute}=", procedure.get_adapter_configuration.attributes[attribute])
          end
          
          %w(host port socket).each do |attribute|
            send(:"#{attribute}=", procedure.get_adapter_configuration.get_options.attributes[attribute])
          end

          self.dumped_file      = "#{timestamp}.#{trigger.gsub(' ', '-')}.sql"      
          self.compressed_file  = "#{dumped_file}.gz"
          self.encrypted_file   = "#{compressed_file}.enc"
          self.final_file       = compressed_file
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
          if skip_tables.is_a?(Array)
            skip_tables.map {|table| " --ignore-table='#{database}.#{table}' "}
          elsif skip_tables.is_a?(String)
            " --ignore-table='#{database}.#{skip_tables}' "
          else
            ""
          end
        end
                
    end
  end
end
