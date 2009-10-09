module Backup
  module Adapter
    class Assets < Backup::Base
    
      def initialize(options = {})
        super(default_options.merge(options))
        setup_paths("assets/#{self.class.name.downcase.gsub('::','-')}", 'tar.gz')
      end
    
      # Initialize the process
      # Executing multiple processes
      # 
      # - Archive
      #   Archives the specified folder to a .tar
      # - Compress
      #   Compresses the .tar file using Gzip
      # - Encrypt
      #   Encrypts the backup file
      # - Transfer
      #   Initializes the transfer to either S3 or using SSH
      # - Records
      #   Records the Backup Data to the Backup SQLite3 database
      # - Remove Temp Files
      #   Removes temporary files after the process is complete
      def run
        archive
        compress
        encrypt
        transfer
        record
        remove_temp_files
      end
    
      private
      
        # Archives the assets into a .tar file and stores it
        # inside the "Backup Path"
        def archive
          %x{ tar -cf #{File.join(options[:backup_path], options[:backup_file])} #{options[:path]} }
        end
      
        # Compresses the .tar file to .tar.gz and removes the old .tar file
        def compress
          %x{ gzip --best #{File.join(options[:backup_path], options[:backup_file])} }
        end
      
        # Set default options
        def default_options
          { :path => "#{RAILS_ROOT}/public/assets", :file => "assets" }
        end
    
    end
  end
end