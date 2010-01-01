module Backup
  module Adapters
    class MySQL < Backup::Adapters::Base
      
      attr_accessor :dumped_file, :compressed_file, :encrypted_file, :user, :password, :database, :skip_tables, :host, :port, :socket, :additional_options
      
      # Initializes the Backup Process
      # 
      # This will first load in any prefixed settings from the Backup::Adapters::Base
      # Then it will add it's own settings.
      # 
      # First it will create a compressed MySQL dump 
      # Then it will optionally encrypt the backed up file
      # Then it will store it to the specified storage location
      # Then it will record the data to the database
      # Once this is all done, all the temporary files will be removed
      # 
      # Wrapped inside of begin/ensure/end block to ensure the deletion of any files in the tmp directory
      def initialize(trigger, procedure)
        super
        load_settings
        
        begin
          mysqldump
          encrypt
          store
          record
          notify
        ensure
          remove_tmp_files
        end
      end
      
      private
        
        # Dumps and Compresses the MySQL file 
        def mysqldump
          puts system_messages[:mysqldump]; puts system_messages[:compressing]
          %x{ mysqldump -u #{user} --password='#{password}' #{options} #{additional_options} #{database} #{tables_to_skip} | gzip -f --best > #{File.join(tmp_path, compressed_file)} }
        end
        
        # Encrypts the MySQL file
        def encrypt
          if encrypt_with_password.is_a?(String)
            puts system_messages[:encrypting]
            %x{ openssl enc -des-cbc -in #{File.join(tmp_path, compressed_file)} -out #{File.join(tmp_path, encrypted_file)} -k #{encrypt_with_password} }
            self.final_file = encrypted_file
          end
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