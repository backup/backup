module Backup
  class Assets < Backup::Base
    
    def initialize(options = {})
      super(default_options.merge(options))
      setup_paths("assets/#{self.class.name.downcase.gsub('::','-')}", 'tar.gz')
    end
    
    def run
      archive
      compress
      transfer
      remove_temp_files
    end
    
    private
      
      def archive
        %x{ tar -cf #{File.join(options[:backup_path], options[:backup_file])} #{options[:path]} }
      end
      
      def compress
        %x{ gzip --best #{File.join(options[:backup_path], options[:backup_file])} }
      end
      
      def default_options
        { :path => "#{RAILS_ROOT}/public/assets", :file => "assets" }
      end
    
  end
end