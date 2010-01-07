module Backup
  module Adapters
    class Archive < Backup::Adapters::Base
      
      private

        # Archives and Compresses all files
        def perform
          files = procedure.get_adapter_configuration.attributes['files']
          log system_messages[:archiving]; log system_messages[:compressing]
          run "tar -czf #{File.join(tmp_path, compressed_file)} #{[*files].map{|f| f.gsub(' ', '\ ')}.join(' ')}"
        end

        def performed_file_extension
          "tar"
        end
        
    end
  end
end
