module Backup
  module Transfer
    class Base
      
      attr_accessor :options
      
      def initialize(options)
        self.options = options
      end
    
      private
      
        def remove_temp_files
          %x{ rm #{File.join(options[:backup_path], "*")} }
        end
      
    end
  end
end