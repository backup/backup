module Backup
  class Custom < Backup::Base
    
    def initialize(options = {})
      super(default_options.merge(options))
      setup_paths("db/#{self.class.name.downcase.gsub('::','-')}", options[:file].is_a?(Array) ? 'tar.gz' : 'gz')
    end
    
    def run
      command
      archive
      compress
      transfer
      remove_temp_files
      remove_original_file unless options[:keep_original_files].eql?(true)
    end
    
    private
    
      def command
        if options[:command].is_a?(Array)
          options[:command].each do |command|
            %x{ #{command} }
          end
        else
          %x{ #{options[:command]} }
        end
      end
      
      def archive
        if options[:file].is_a?(Array)
          files = options[:file].map {|file| File.join(options[:path], file)}
          %x{ tar -cf #{File.join(options[:backup_path], options[:backup_file])} #{files.join(' ')} }
        else
          %x{ tar -cf #{File.join(options[:backup_path], options[:backup_file])} #{File.join(options[:path], options[:file])} }
        end
      end
      
      def compress
        if options[:file].is_a?(Array)
          %x{ gzip --best #{File.join(options[:backup_path], options[:backup_file])} }
        else
          %x{ gzip -cv #{File.join(options[:path], options[:file])} --best > #{File.join(options[:backup_path], options[:backup_file])} }
        end
      end
      
      def default_options
        { :path     => "",
          :file     => "",
          :command  => "",
          :keep_original_files => false }
      end
    
  end  
end