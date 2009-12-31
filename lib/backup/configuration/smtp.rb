module Backup
  module Configuration
    class SMTP
      
      attr_accessor :attributes 
      
      %w(host port username password authentication domain tls).each do |method|
        define_method method do |value|
          attributes[method.to_sym] = value
        end
      end

      def initialize
        @attributes = {}
      end
      
    end
  end
end