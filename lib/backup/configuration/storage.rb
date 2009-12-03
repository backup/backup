module Backup
  module Configuration
    class Storage
      attr_accessor :attributes 

      %w(ip user password path access_key_id secret_access_key use_ssl bucket).each do |method|
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