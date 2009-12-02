module Backup
  module Adapters
    class MySQL < Backup::Adapters::Base
      
      attr_accessor :dumped_file, :compressed_file, :encrypted_file, :user, :password, :database
      
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
          %x{ mysqldump -u #{user} --password='#{password}' #{database} | gzip -f --best > #{File.join(tmp_path, compressed_file)} }
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
          self.user     = procedure.get_adapter_configuration.attributes['user']
          self.password = procedure.get_adapter_configuration.attributes['password']
          self.database = procedure.get_adapter_configuration.attributes['database']

          self.dumped_file      = "#{timestamp}.#{trigger.gsub(' ', '-')}.sql"      
          self.compressed_file  = "#{dumped_file}.gz"
          self.encrypted_file   = "#{compressed_file}.enc"
          self.final_file       = compressed_file
        end
        
    end
  end
end