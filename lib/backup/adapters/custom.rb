module Backup
  module Adapters
    class Custom < Backup::Adapters::Base
      
      attr_accessor :archived_file, :compressed_file, :encrypted_file, :commands
      
      # Initializes the Backup Process
      # 
      # This will first load in any prefixed settings from the Backup::Adapters::Base
      # Then it will add it's own settings.
      # 
      # First it will execute any given commands
      # Then it will archive and compress every folder/file
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
          execute_commands
          targz
          encrypt
          store
          record
          notify
        ensure
          remove_tmp_files
        end
      end
      
      private
        
        # Executes the commands
        def execute_commands
          if commands.is_a?(Array)
            puts system_messages[:commands]
            commands.each do |command|
              %x{ #{command.gsub(':tmp_path', tmp_path)} }
            end
          elsif commands.is_a?(String)
            puts system_messages[:commands]
            %x{ #{commands.gsub(':tmp_path', tmp_path)} }
          end
        end
        
        # Archives and Compresses
        def targz
          puts system_messages[:archiving]; puts system_messages[:compressing]
          %x{ tar -czf #{File.join(tmp_path, compressed_file)} #{File.join(tmp_path, '*')} }
        end
        
        # Encrypts the archive file
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
          self.commands = procedure.get_adapter_configuration.attributes['commands']
          
          self.archived_file    = "#{timestamp}.#{trigger.gsub(' ', '-')}.tar"      
          self.compressed_file  = "#{archived_file}.gz"
          self.encrypted_file   = "#{compressed_file}.enc"
          self.final_file       = compressed_file
        end
                
    end
  end
end