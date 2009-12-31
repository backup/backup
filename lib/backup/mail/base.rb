module Backup
  module Mail
    class Base
      
      def self.setup(config)
        require 'pp'
        pp config
        exit
      end
      
    end
  end
end