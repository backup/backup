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
        options[:backup_file] = "#{backup_time}-#{options[:file]}.#{type}"
      end
    
      def transfer
        case options[:use]
          when :s3  then Backup::Transfer::S3.new(options)
          when :ssh then Backup::Transfer::SSH.new(options)
        end
      end

  end
end