module Backup
  module Configuration
    class Adapter
      
      attr_accessor :attributes 
      
      %w(files user password database skip_tables commands additional_options).each do |method|
        define_method method do |value|
          attributes[method] = value
        end
      end

      def initialize
        @attributes = {}
        @options    = Backup::Configuration::AdapterOptions.new
      end

      def options(&block)
        @options.instance_eval &block
      end
      
      def get_options
        @options
      end

    end
  end
end