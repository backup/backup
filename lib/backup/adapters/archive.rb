module Backup
  module Adapters
    class Archive < Backup::Adapters::Base
      
      attr_accessor :files, :exclude
      
      private

        # Archives and Compresses all files
        def perform
          log system_messages[:archiving]; log system_messages[:compressing]
          run "tar -czf #{File.join(tmp_path, compressed_file)} #{exclude_files} #{tar_files}"
        end
        
        def load_settings
          self.files   = procedure.get_adapter_configuration.attributes['files']
          self.exclude = procedure.get_adapter_configuration.attributes['exclude']
        end

        def performed_file_extension
          ".tar"
        end
        
        def tar_files
          [*files].map{|f| f.gsub(' ', '\ ')}.join(' ')
        end

        def exclude_files
          [*exclude].compact.map{|x| "--exclude=#{x}"}.join(' ')
        end

    end
  end
end
