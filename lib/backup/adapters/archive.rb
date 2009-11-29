module Backup
  module Adapters
    class Archive < Backup::Adapters::Base
      
      attr_accessor :archived_file, :compressed_file, :encrypted_file, :user, :password, :database
      
      # Initializes the Backup Process
      def initialize(trigger, procedure)
        super
        load_settings
        
        targz
        encrypt
        store
        record
        remove_tmp_files
      end
      
      private
        
        # Archives and Compresses all files
        def targz
          files = procedure.get_adapter_configuration.attributes['files']
          if files.is_a?(Array)
            %x{ tar -czf #{File.join(tmp_path, compressed_file)} #{files.map{|f| f.gsub(' ', '\ ')}.join(' ')} }
          elsif files.is_a?(String)
            %x{ tar -czf #{File.join(tmp_path, compressed_file)} #{files.gsub(' ', '\ ')} }
          end
        end
        
        # Encrypts the Archive
        def encrypt
          if encrypt_with_password.is_a?(String)
            %x{ openssl enc -des-cbc -in #{File.join(tmp_path, compressed_file)} -out #{File.join(tmp_path, encrypted_file)} -k #{encrypt_with_password} }
            self.final_file = encrypted_file
          end
        end
        
        # Loads the initial settings
        def load_settings
          self.user     = procedure.get_adapter_configuration.attributes['user']
          self.password = procedure.get_adapter_configuration.attributes['password']
          self.database = procedure.get_adapter_configuration.attributes['database']

          self.archived_file    = "#{timestamp}.archive.#{trigger.gsub(' ', '-')}.tar"      
          self.compressed_file  = "#{archived_file}.gz"
          self.encrypted_file   = "#{compressed_file}.enc"
          self.final_file       = compressed_file
        end
        
    end
  end
end