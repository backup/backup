module Backup
  class Mysql < Backup::Base
    
    def initialize(options = {})
      super(default_options.merge(options))
      setup_paths("db/#{self.class.name.downcase.gsub('::','-')}", :gz)
    end
    
    def run
      make_mysql_dump
      compress
      transfer
    end

    private
    
      def compress
        %x{ gzip -cv #{File.join(options[:path], options[:file])} --best > #{File.join(options[:backup_path], options[:backup_file])} }
      end
    
      def make_mysql_dump
        # => /usr/local/mysql/bin/mysqldump on Mac OS X 10.6
        %x{ mysqldump --quick -u #{options[:mysql][:user]} --password='#{options[:mysql][:password]}' #{options[:mysql][:database]} > #{File.join(options[:path], options[:file])} }
      end
    
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