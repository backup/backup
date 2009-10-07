module Backup
  class Base
    
    attr_accessor :options, :backup_time
    
    def initialize(options = {})
      self.options      = options
      self.backup_time  = Time.now.strftime("%Y%m%d%H%M%S") 
    end
    
    private
      
      # Sets up the default paths and stores them in the options hash
      # It also ensures the directory to where the temporary files are stored
      # exists. If it doesn't it'll be created
      # It will store the backup_path and the backup_file names
      # The backup_file name is prefixed with the timestamp of the initialize time.
      def setup_paths(path, type = nil)
        %x{ mkdir -p #{RAILS_ROOT}/tmp/backups/#{path} }
        options[:backup_path] = "#{RAILS_ROOT}/tmp/backups/#{path}"
        
        if options[:file].is_a?(Array)
          options[:backup_file] = "#{backup_time}-#{options[:file].first}.#{type}"
        else
          options[:backup_file] = "#{backup_time}-#{options[:file]}.#{type}"
        end
      end
    
      # Initializes one of the transfer methods
      # Currently there are two transfer methods available
      #
      # - Amazon S3
      # - SSH
      def transfer
        case options[:use]
          when :s3  then Backup::Transfer::S3.new(options)
          when :ssh then Backup::Transfer::SSH.new(options)
        end
      end
      
      # Records a backup to the "backup.sqlite3" database
      # Will destroy any old backups that exceed the amount of
      # backups that are allowed to be stored on either S3 or any
      # remote server through SSH.
      def record        
        case options[:use]
          when :s3
            backup = Backup::BackupRecord::S3.new
            backup.set_options(options)
            backup.save
          
          when :ssh
            backup = Backup::BackupRecord::SSH.new
            backup.set_options(options)
            backup.save
        end
      end
      
      # Encrypts the backup file
      # Only if the encrypt option is specified inside the .yml config file
      # Otherwise, the encryption will be not be executed.
      # Encryption is OPTIONAL.
      def encrypt
        unless options[:encrypt].blank?
          Backup::Encrypt.new(options).run
          options[:backup_file] = "#{options[:backup_file]}.enc"
        end
      end
      
      # Removes files that were stored in the tmp/backups/* directory of the Rails application
      # It completely cleans up the backup folders so theres no trash stored on the production server
      def remove_temp_files
        %x{ rm #{File.join(options[:backup_path], "*")} }
      end
      
      # Removes files that were generated for the transfer
      # This can remove either a single file or an array of files
      # Depending on whether the options[:file] is an Array or a String
      def remove_original_file
        unless options[:keep_original_files].eql?(true)
          if options[:file].is_a?(Array)
            options[:file].each do |file|
              %x{ rm #{File.join(options[:path], file)} }          
            end
          else
            %x{ rm #{File.join(options[:path], options[:file])} }
          end
        end
      end
      
  end
end