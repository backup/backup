module Backup
  module Environment
    module Base
      
      def current_environment
        return :rails if defined?(Rails.root)
        return :unix
      end
      
    end
  end
end