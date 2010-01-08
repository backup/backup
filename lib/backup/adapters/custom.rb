module Backup
  module Adapters
    class Custom < Backup::Adapters::Base
      
      attr_accessor :commands
      
      private

        # Execute any given commands, then archive and compress every folder/file
        def perform
          execute_commands
          targz
        end
        
        # Executes the commands
        def execute_commands
          return unless commands
          log system_messages[:commands]
          [*commands].each do |command|
            run "#{command.gsub(':tmp_path', tmp_path)}"
          end
        end
        
        # Archives and Compresses
        def targz
          log system_messages[:archiving]; log system_messages[:compressing]
          run "tar -czf #{File.join(tmp_path, compressed_file)} #{File.join(tmp_path, '*')}"
        end
        
        def performed_file_extension
          ".tar"
        end

        # Loads the initial settings
        def load_settings
          self.commands = procedure.get_adapter_configuration.attributes['commands']
        end
                
    end
  end
end
