module Backup
  module Environment
    module Base
      
      def current_environment
        return :rails if defined?(RAILS_ENV)
        return :unix
      end
      
    end
  end
end