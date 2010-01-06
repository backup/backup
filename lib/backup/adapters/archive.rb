module Backup
  module Adapters
    class Archive < Backup::Adapters::Base
      
      attr_accessor :archived_file, :compressed_file, :encrypted_file
      
      private

        # Archives and Compresses all files
        def perform
          files = procedure.get_adapter_configuration.attributes['files']
          if files.is_a?(Array)
            puts system_messages[:archiving]; puts system_messages[:compressing]
            %x{ tar -czf #{File.join(tmp_path, compressed_file)} #{files.map{|f| f.gsub(' ', '\ ')}.join(' ')} }
          elsif files.is_a?(String)
            puts system_messages[:archiving]; puts system_messages[:compressing]
            %x{ tar -czf #{File.join(tmp_path, compressed_file)} #{files.gsub(' ', '\ ')} }
          end
        end
        
        # Loads the initial settings
        def load_settings
          self.trigger  = procedure.trigger

          self.archived_file    = "#{timestamp}.#{trigger.gsub(' ', '-')}.tar"      
          self.compressed_file  = "#{archived_file}.gz"
          self.encrypted_file   = "#{compressed_file}.enc"
          self.final_file       = compressed_file
        end
        
    end
  end
end
