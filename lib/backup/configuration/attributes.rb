module Backup
  module Configuration
    module Attributes
      
      def generate_attributes(*attrs)
        define_method :attributes do
          @attributes ||= {}
        end
        
        attrs.flatten.each do |att|
          define_method att do |value|
            self.attributes[att.to_s] = value
          end
        end
      end
    end
  end
end

