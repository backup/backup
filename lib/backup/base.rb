module Backup
  class Base
    
    attr_accessor :options, :backup_time
    
    def initialize(options = {})
      self.options      = options
      self.backup_time  = Time.now.strftime("%Y%m%d%H%M%S") 
    end
    
    private
    
      def setup_paths(path, type = nil)
        %x{ mkdir -p #{RAILS_ROOT}/tmp/backups/#{path} }
        options[:backup_path] = "#{RAILS_ROOT}/tmp/backups/#{path}"
        
        if options[:file].is_a?(Array)
          options[:backup_file] = "#{backup_time}-#{options[:file].first}.#{type}"
        else
          options[:backup_file] = "#{backup_time}-#{options[:file]}.#{type}"
        end
      end
    
      def transfer
        case options[:use]
          when :s3  then Backup::Transfer::S3.new(options)
          when :ssh then Backup::Transfer::SSH.new(options)
        end
      end
      
      def remove_temp_files
        %x{ rm #{File.join(options[:backup_path], "*")} }
      end
      
      def remove_original_file
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