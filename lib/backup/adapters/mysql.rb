module Backup
  module Adapters
    class MySQL < Backup::Adapters::Base
      
      attr_accessor :dumped_file, :compressed_file, :encrypted_file, :user, :password, :database, :skip_tables, :host, :port, :socket
      
      # Initializes the Backup Process
      def initialize(trigger, procedure)
        super
        load_settings
        
        begin
          mysqldump
          encrypt
          store
          record
        ensure
          remove_tmp_files
        end
      end
      
      private
        
        # Dumps and Compresses the MySQL file 
        def mysqldump
          %x{ mysqldump  -u #{user}  --password='#{password}' #{options} #{database} #{tables_to_skip} | gzip -f --best > #{File.join(tmp_path, compressed_file)} }
        end
        
        # Encrypts the MySQL file
        def encrypt
          if encrypt_with_password.is_a?(String)
            %x{ openssl enc -des-cbc -in #{File.join(tmp_path, compressed_file)} -out #{File.join(tmp_path, encrypted_file)} -k #{encrypt_with_password} }
            self.final_file = encrypted_file
          end
        end
        
        # Loads the initial settings
        def load_settings
          self.trigger  = procedure.trigger
          
          %w(user password database skip_tables).each do |attribute|
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
        
        def options
          options = String.new
          options += " --host='#{host}' "     unless host.blank?
          options += " --port='#{port}' "     unless port.blank?
          options += " --socket='#{socket}' " unless socket.blank?
          options
        end
        
        def tables_to_skip
          if skip_tables.is_a?(Array)
            skip_tables.map {|table| " --ignore-table='#{database}.#{table}' "}
          elsif skip_tables.is_a?(String)
            "--ignore-table=#{database}.#{skip_tables}"
          else
            ""
          end
        end
                
    end
  end
end