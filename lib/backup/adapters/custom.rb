module Backup
  module Adapters
    class Custom < Backup::Adapters::Base
      
      attr_accessor :archived_file, :compressed_file, :encrypted_file, :commands
      
      # Initializes the Backup Process
      def initialize(trigger, procedure)
        super
        load_settings
        
        begin
          execute_commands
          targz
          encrypt
          store
          record
        ensure
          remove_tmp_files
        end
      end
      
      private
        
        # Executes the commands
        def execute_commands
          if commands.is_a?(Array)
            commands.each do |command|
              %x{ #{command.gsub(':tmp_path', tmp_path)} }
            end
          elsif commands.is_a?(String)
            %x{ #{commands.gsub(':tmp_path', tmp_path)} }
          end
        end
        
        # Archives and Compresses
        def targz
          %x{ tar -czf #{File.join(tmp_path, compressed_file)} #{File.join(tmp_path, '*')} }
        end
        
        # Encrypts the archive file
        def encrypt
          if encrypt_with_password.is_a?(String)
            %x{ openssl enc -des-cbc -in #{File.join(tmp_path, compressed_file)} -out #{File.join(tmp_path, encrypted_file)} -k #{encrypt_with_password} }
            self.final_file = encrypted_file
          end
        end
        
        # Loads the initial settings
        def load_settings
          self.trigger  = procedure.trigger
          self.commands = procedure.get_adapter_configuration.attributes['commands']
          
          self.archived_file    = "#{timestamp}.#{trigger.gsub(' ', '-')}.tar"      
          self.compressed_file  = "#{archived_file}.gz"
          self.encrypted_file   = "#{compressed_file}.enc"
          self.final_file       = compressed_file
        end
                
    end
  end
end