module Backup
  module Configuration
    module Attributes
      
      def generate_attributes(*attrs)
        attr_accessor :attributes
        
        attrs.flatten.each do |att|
          define_method att do |value|
            self.attributes ||= {}
            self.attributes[att.to_sym] = value
          end
        end
      end
    end
  end
end

