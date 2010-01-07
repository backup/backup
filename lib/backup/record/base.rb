module Backup
  module Record
    class Base < ActiveRecord::Base
      
      if DB_CONNECTION_SETTINGS
        establish_connection(DB_CONNECTION_SETTINGS)
      end
      
      set_table_name 'backup'
      
      default_scope :order => 'created_at desc'

      # Callbacks
      after_save :clean_backups
      
      # Attributes
      attr_accessor :adapter_config, :keep_backups
      
      # Receives the options hash and stores it
      def load_adapter(adapter)
        self.adapter_config = adapter
        self.trigger        = adapter.procedure.trigger
        self.adapter        = adapter.procedure.adapter_name.to_s
        self.filename       = adapter.final_file
        self.keep_backups   = adapter.procedure.attributes['keep_backups']
        
        # TODO calculate md5sum of file
        load_specific_settings(adapter) if respond_to?(:load_specific_settings)
      end
      
      # Destroys all backups for the specified trigger from Remote Server (FTP)
      def self.destroy_all_backups(procedure, trigger)
        backups = self.all(:conditions => {:trigger => trigger})
        unless backups.empty?
          # Derived classes must implement this method!
          self.destroy_backups(procedure, backups)
          
          puts "\nAll \"#{procedure.trigger}\" backups destroyed.\n\n"
        end
      end
      
      private
      
        # Maintains the backup file amount on the remote server
        # This is invoked after a successful record save
        # This deletes the oldest files when the backup limit has been exceeded
        def clean_backups
          if keep_backups.is_a?(Integer)
            backups = self.class.all(:conditions => {:trigger => trigger})
            backups_to_destroy = backups[keep_backups, backups.size] || []
            
            unless backups_to_destroy.empty?
              # Derived classes must implement this method!
              self.class.destroy_backups(adapter_config.procedure, backups_to_destroy)
              
              puts "\nBackup storage for \"#{trigger}\" is limited to #{keep_backups} backups."
              puts "\nThe #{keep_backups} most recent backups are now stored on the remote server.\n\n"
            end
          end
        end
        
    end
  end
end

