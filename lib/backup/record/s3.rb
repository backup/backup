module Backup
  module Record
    class S3 < ActiveRecord::Base
      
      if DB_CONNECTION_SETTINGS
        establish_connection(DB_CONNECTION_SETTINGS)
      end
      
      set_table_name 'backup'
      default_scope \
        :order => 'created_at desc',
        :conditions => {:storage => 's3'}

      # Callbacks
      after_save :clean_backups
      
      # Attributes
      attr_accessor :adapter_config, :keep_backups
      
      # Receives the options hash and stores it
      # Sets the S3 values
      def load_adapter(adapter)
        self.adapter_config = adapter
        self.storage        = 's3'
        self.trigger        = adapter.procedure.trigger
        self.adapter        = adapter.procedure.adapter_name.to_s
        self.filename       = adapter.final_file
        self.bucket         = adapter.procedure.get_storage_configuration.attributes['bucket']
        self.keep_backups   = adapter.procedure.attributes['keep_backups']
      end
      
      # Destroys all backups for the specified trigger from Amazon S3
      def self.destroy_all_backups(procedure, trigger)
        backups = Backup::Record::S3.all(:conditions => {:trigger => trigger})        
        unless backups.empty?
          s3 = Backup::Connection::S3.new
          s3.static_initialize(procedure)
          s3.connect
          backups.each do |backup|
            puts "\nDestroying backup \"#{backup.filename}\" from bucket \"#{backup.bucket}\"."
            s3.destroy(backup.filename, backup.bucket)
            backup.destroy
          end
          puts "\nAll \"#{trigger}\" backups destroyed.\n\n"
        end
      end
      
      private
        
        # Maintains the backup file amount on S3
        # This is invoked after a successful record save
        # This deletes the oldest files when the backup limit has been exceeded
        def clean_backups
          if keep_backups.is_a?(Integer)
            backups = Backup::Record::S3.all(:conditions => {:trigger => trigger})
            backups_to_destroy = Array.new
            backups.each_with_index do |backup, index|
              if index >= keep_backups then
                backups_to_destroy << backup
              end
            end
            
            unless backups_to_destroy.empty?
              s3 = Backup::Connection::S3.new(adapter_config)
              s3.connect
              backups_to_destroy.each do |backup|
                puts "\nDestroying backup \"#{backup.filename}\" from bucket \"#{backup.bucket}\"."
                s3.destroy(backup.filename, backup.bucket)
                backup.destroy
              end
              
              puts "\nBackup storage for \"#{trigger}\" is limited to #{keep_backups} backups."
              puts "\nThe #{keep_backups} most recent backups are now stored on S3.\n\n"
            end
          end
        end
        
    end
  end
end