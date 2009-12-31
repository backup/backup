module Backup
  module Configuration
    class Mail
      attr_accessor :attributes

      %w(from to smtp).each do |method|
        define_method method do |value|
          attributes[method.to_sym] = value
        end
      end

      def initialize
        @attributes = {}
        @smtp_configuration = Backup::Configuration::SMTP.new
      end

      def smtp(&block)
        @smtp_configuration.instance_eval &block
      end
    
      def get_smtp_configuration
        @smtp_configuration
      end
    end
  end
end