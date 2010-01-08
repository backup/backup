module Backup
  module Adapters
    class SQLite < Base
      
      attr_accessor :database
      
      private

        # Compress the sqlite file
        def perform
          log system_messages[:sqlite]
          run "gzip -c --best #{database} > #{File.join(tmp_path, compressed_file)}"
        end
        
        def load_settings
          self.database = procedure.get_adapter_configuration.attributes['database']
        end
        
        def performed_file_extension
          ""
        end

    end
  end
end
