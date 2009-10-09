require 'net/ssh'

module Backup
  module BackupRecord
    class SSH < ActiveRecord::Base
        
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
      attr_accessor :options, :keep_backups, :ip, :user
      
      # Receives the options hash and stores it
      # Sets the S3 values
      def set_options(options)
        self.options      = options
        self.backup_file  = options[:backup_file]
        self.backup_path  = options[:ssh][:path]
        self.keep_backups = options[:keep_backups]
        self.adapter      = options[:adapter]
        self.index        = options[:index]
        self.ip           = options[:ssh][:ip]
        self.user         = options[:ssh][:user]
      end
      
      # This will only be triggered by the rake task
      # rake backup:db:destroy:ssh
      # 
      # This will loop through all the configured adapters
      # and destroy all "Backup" database records for the
      # SSH table and delete all backed up files from the
      # remote server on which they are stored.
      def self.destroy_all_backups(adapter, options, index)
        backups = Backup::BackupRecord::SSH.all(:conditions => {:adapter => adapter, :index => index})
        unless backups.empty?
          Net::SSH.start(options['ssh']['ip'], options['ssh']['user']) do |ssh|
            # Loop through all backups that should be destroyed and remove them from remote server.
            backups.each do |backup|
              puts "Destroying old backup: #{backup.backup_file}.."
              ssh.exec("rm #{File.join(backup.backup_path, backup.backup_file)}")
              backup.destroy
            end
          end
        end
      end

      private
        
        # Destroys backups when the backup limit has been reached
        # This is determined by the "keep_backups:" parameter
        # First all backups will be fetched. 
        def destroy_old_backups
          if keep_backups.is_a?(Integer)
            backups = Backup::BackupRecord::SSH.all(:conditions => {:adapter => adapter, :index => index})
            backups_to_destroy = Array.new
            backups.each_with_index do |backup, index|
              if index >= keep_backups then
                backups_to_destroy << backup
              end
            end
          
            if backups_to_destroy
              # Establish a connection with the remote server through SSH
              Net::SSH.start(ip, user) do |ssh|
                # Loop through all backups that should be destroyed and remove them from remote server.
                backups_to_destroy.each do |backup|
                  puts "Destroying old backup: #{backup.backup_file}.."
                  ssh.exec("rm #{File.join(backup.backup_path, backup.backup_file)}")
                  backup.destroy
                end
              end
            end
          end
        end
        
    end
  end
end