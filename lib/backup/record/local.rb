module Backup
  module Record
    class Local < Backup::Record::Base
      
      def load_specific_settings(adapter)
        self.path = adapter.procedure.get_storage_configuration.attributes['path']
      end
      
      private
        
        class << self
          include Backup::CommandHelper
        
          def destroy_backups(procedure, backups)
            backups.each do |backup|
              puts "\nDestroying backup \"#{backup.filename}\" from path \"#{backup.path}\"."
              run "rm #{File.join(backup.path, backup.filename)}"
              backup.destroy
            end
          end
        end
        
    end
  end
end

