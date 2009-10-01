module Backup
  class Sqlite3 < Backup::Base
    
    def initialize(options = {})
      super(default_options.merge(options))
      setup_paths("db/#{self.class.name.downcase.gsub('::','-')}", :gz)
    end
    
    def run
      compress
      transfer
    end
    
    private
      
      def compress
        %x{ gzip -cv #{File.join(options[:path], options[:file])} --best > #{File.join(options[:backup_path], options[:backup_file])} }
      end
      
      def default_options
        { :path => "#{RAILS_ROOT}/db",
          :file => "production.sqlite3" }
      end
    
  end  
end