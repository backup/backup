module Backup
  module Connection
    class Base
      
      attr_accessor :options
      
      def initialize(options)
        self.options = options
      end

    end
  end
end