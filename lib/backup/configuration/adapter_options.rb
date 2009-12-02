module Backup
  module Configuration
    class AdapterOptions
      
      attr_accessor :attributes 
      
      %w(host port socket).each do |method|
        define_method method do |value|
          attributes[method] = value
        end
      end

      def initialize
        @attributes = {}
      end
      
    end
  end
end