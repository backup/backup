module Backup
  module Adapters
    class Archive < Backup::Adapters::Base
      
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

        def performed_file_extension
          "tar"
        end
        
    end
  end
end
