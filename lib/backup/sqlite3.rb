module Backup
  class Sqlite3 < Backup::Base
    
    def initialize(options = {})
      super(default_options.merge(options))
      setup_paths("db/#{self.class.name.downcase.gsub('::','-')}", :gz)
    end
    
    # Initialize the process
    # Executing multiple processes
    #
    # - Compress
    #   Compresses the .tar file using Gzip
    # - Encrypt
    #   Encrypts the backup file
    # - Transfer
    #   Initializes the transfer to either S3 or using SSH
    # - Remove Temp Files
    #   Removes temporary files after the process is complete
    def run
      compress
      encrypt
      transfer
      remove_temp_files
    end
    
    private
      
      # Compresses the SQLite3file and stores the compressed version inside the tmp/backups folder.
      def compress
        %x{ gzip -cv #{File.join(options[:path], options[:file])} --best > #{File.join(options[:backup_path], options[:backup_file])} }
      end
      
      # Set default options
      def default_options
        { :path => "#{RAILS_ROOT}/db",
          :file => "production.sqlite3" }
      end
    
  end  
end