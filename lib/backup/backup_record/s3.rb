require 'aws/s3'

module Backup
  module BackupRecord
    class S3 < ActiveRecord::Base
        
      # Establishes a connection with the SQLite3
      # local database to avoid conflict with users
      # Production database.
      establish_connection(
        :adapter  => "sqlite3",
        :database => "db/backup.sqlite3",
        :pool     => 5,
        :timeout  => 5000 )
      
      # Scopes
      default_scope :order => 'created_at desc'
      
      # Callbacks
      after_save :destroy_old_backups
      
      # Attributes
      attr_accessor :options, :keep_backups
      
      # Receives the options hash and stores it
      # Sets the S3 values
      def set_options(options)
        self.options      = options
        self.backup_file  = options[:backup_file]
        self.bucket       = options[:s3][:bucket]
        self.keep_backups = options[:keep_backups]
        self.adapter      = options[:adapter]
      end
      
      def self.destroy_all_backups(adapter, options)
        s3 = Backup::Connection::S3.new(options)
        s3.connect
        backups = Backup::BackupRecord::S3.all(:conditions => {:adapter => adapter})
        backups.each do |backup|
          puts "Destroying backup: #{backup.backup_file}.."
          s3.destroy(backup.backup_file, backup.bucket)
          backup.destroy
        end
      end
      
      private
        
        # Destroys backups when the backup limit has been reached
        # This is determined by the "keep_backups:" parameter
        # First all backups will be fetched. 
        def destroy_old_backups
          if keep_backups.is_a?(Integer)
            backups = Backup::BackupRecord::S3.all(:conditions => {:adapter => adapter})
            backups_to_destroy = Array.new
            backups.each_with_index do |backup, index|
              if index >= keep_backups then
                backups_to_destroy << backup
              end
            end
          
            if backups_to_destroy
              # Create a new Amazon S3 Object
              s3 = Backup::Connection::S3.new(options)
            
              # Connect to Amazon S3 with provided credentials
              s3.connect
          
              # Loop through all backups that should be destroyed and remove them from S3.
              backups_to_destroy.each do |backup|
                puts "Destroying old backup: #{backup.backup_file}.."
                s3.destroy(backup.backup_file, backup.bucket)
                backup.destroy
              end
            end
          end
        end
        
    end
  end
end