module Backup
  class Mysql < Backup::Base
    
    def initialize(options = {})
      super(default_options.merge(options))
      setup_paths("db/#{self.class.name.downcase.gsub('::','-')}", :gz)
    end
    
    # Initialize the process
    # Executing multiple processes
    #
    # - Make MySQL Dump
    #   Creates a MySQL dump based on the parameters provided by the user
    # - Compress
    #   Compresses the .tar file using Gzip
    # - Transfer
    #   Initializes the transfer to either S3 or using SSH
    # - Remove Temp Files
    #   Removes temporary files after the process is complete
    def run
      make_mysql_dump
      compress
      encrypt
      transfer
      remove_temp_files
    end

    private
      
      # Compresses the MySQL dump file and stores the compressed version inside the tmp/backups folder.
      def compress
        %x{ gzip -cv #{File.join(options[:path], options[:file])} --best > #{File.join(options[:backup_path], options[:backup_file])} }
      end
      
      # This will generate a MySQL dump based on the options the user passed in.
      # The MySQL dump will be placed (by default) in the config/db directory so it can be found
      # by the compressor.
      def make_mysql_dump
        # => /usr/local/mysql/bin/mysqldump on Mac OS X 10.6
        %x{ mysqldump --quick -u #{options[:mysql][:user]} --password='#{options[:mysql][:password]}' #{options[:mysql][:database]} > #{File.join(options[:path], options[:file])} }
      end
      
      # Set default options
      def default_options
        {:path => "#{RAILS_ROOT}/tmp/backups/db/#{self.class.name.downcase.gsub('::','-')}",
          :file => "production.sql",
          :mysql => {
            :user     => "",
            :password => "",
            :database => ""
        }}
      end
    
  end  
end