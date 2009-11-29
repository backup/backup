module Backup
  module Configuration
    class Adapter
      attr_accessor :attributes 
      
      %w(files user password database).each do |method|
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