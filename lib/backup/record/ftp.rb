module Backup
  module Record
    class FTP < ActiveRecord::Base
      
      if DB_CONNECTION_SETTINGS
        establish_connection(DB_CONNECTION_SETTINGS)
      end
      
      set_table_name 'backup'
      default_scope \
        :order => 'created_at desc',
        :conditions => {:storage => 'ftp'}

      # Callbacks
      after_save :clean_backups
      
      # Attributes
      attr_accessor :adapter_config, :keep_backups, :ip, :user, :password
      
      # Receives the options hash and stores it
      # Sets the FTP values
      def load_adapter(adapter)
        self.adapter_config = adapter
        self.storage        = 'ftp'
        self.trigger        = adapter.procedure.trigger
        self.adapter        = adapter.procedure.adapter_name.to_s
        self.filename       = adapter.final_file
        self.keep_backups   = adapter.procedure.attributes['keep_backups']
        
        %w(ip user password path).each do |method|
          send(:"#{method}=", adapter.procedure.get_storage_configuration.attributes[method])
        end
      end
      
      # Destroys all backups for the specified trigger from Remote Server (FTP)
      def self.destroy_all_backups(procedure, trigger)
        backups = Backup::Record::FTP.all(:conditions => {:trigger => trigger})        
        unless backups.empty?
          ip        = procedure.get_storage_configuration.attributes['ip']
          user      = procedure.get_storage_configuration.attributes['user']
          password  = procedure.get_storage_configuration.attributes['password']

          Net::FTP.open(ip, user, password) do |ftp|
            backups.each do |backup|
              puts "\nDestroying backup \"#{backup.filename}\" from path \"#{backup.path}\"."
              begin
                ftp.chdir(backup.path)
                ftp.delete(backup.filename)
                backup.destroy
              rescue
                backup.destroy
              end
            end
          end
          
         puts "\nAll \"#{trigger}\" backups destroyed.\n\n"
        end
      end
      
      private
        
        # Maintains the backup file amount on the remote server
        # This is invoked after a successful record save 
        # This deletes the oldest files when the backup limit has been exceeded
        def clean_backups
          if keep_backups.is_a?(Integer)
            backups = Backup::Record::FTP.all(:conditions => {:trigger => trigger})
            backups_to_destroy = Array.new
            backups.each_with_index do |backup, index|
              if index >= keep_backups then
                backups_to_destroy << backup
              end
            end
            
            unless backups_to_destroy.empty?
              Net::FTP.open(ip, user, password) do |ftp|
                backups_to_destroy.each do |backup|
                  puts "\nDestroying backup \"#{backup.filename}\" from path \"#{backup.path}\"."
                  begin
                    ftp.chdir(backup.path)
                    ftp.delete(backup.filename)
                    backup.destroy
                  rescue
                    puts "Could not find backup #{backup.path}/#{backup.filename}.."
                    backup.destroy
                  end
                end
              end
              
              puts "\nBackup storage for \"#{trigger}\" is limited to #{keep_backups} backups."
              puts "\nThe #{keep_backups} most recent backups are now stored on the remote server.\n\n"
            end
          end
        end
        
    end
  end
end