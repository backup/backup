module Backup
  class Custom < Backup::Base
    
    def initialize(options = {})
      super(default_options.merge(options))
      setup_paths("db/#{self.class.name.downcase.gsub('::','-')}", options[:file].is_a?(Array) ? 'tar.gz' : 'gz')
    end
    
    # Initialize the process
    # Executing multiple processes
    #
    # - Command
    #   Executes a command from a user to generate a SQL dump
    # - Archive
    #   Archives the specified folder to a .tar
    # - Compress
    #   Compresses the .tar file using Gzip
    # - Transfer
    #   Initializes the transfer to either S3 or using SSH
    # - Remove Temp Files
    #   Removes temporary files after the process is complete
    # - Remove Original File
    #   Removes the user generated sql files (unless the user specifies he wants to keep them)
    def run
      command
      archive
      compress
      transfer
      remove_temp_files
      remove_original_file unless options[:keep_original_files].eql?(true)
    end
    
    private
      
      # Allows a user to insert one or more commands to be executed
      # before the actual archive, compress and transferring processes.
      # The command takes either a String for a single command, and an Array for multiple commands.
      def command
        if options[:command].is_a?(Array)
          options[:command].each do |command|
            %x{ #{command} }
          end
        else
          %x{ #{options[:command]} }
        end
      end
      
      # Archives the assets into a .tar file and stores it
      # inside the "Backup Path"
      def archive
        if options[:file].is_a?(Array)
          files = options[:file].map {|file| File.join(options[:path], file)}
          %x{ tar -cf #{File.join(options[:backup_path], options[:backup_file])} #{files.join(' ')} }
        else
          %x{ tar -cf #{File.join(options[:backup_path], options[:backup_file])} #{File.join(options[:path], options[:file])} }
        end
      end
      
      # If the user has bundled a couple of files to a .tar (by using an Array for the :file attribute)
      # then it compresses the .tar file to .tar.gz and removes the old .tar file
      # If the user has only a single file, it will be read out and a new file will be generated
      # The old (single) file will remain until the process is complete, unless the user specifies otherwise.
      def compress
        if options[:file].is_a?(Array)
          %x{ gzip --best #{File.join(options[:backup_path], options[:backup_file])} }
        else
          %x{ gzip -cv #{File.join(options[:path], options[:file])} --best > #{File.join(options[:backup_path], options[:backup_file])} }
        end
      end
      
      # Set default options
      def default_options
        { :path     => "",
          :file     => "",
          :command  => "",
          :keep_original_files => false }
      end
    
  end  
end