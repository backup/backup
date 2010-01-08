module Backup
  module Configuration
    class Mail
      extend Backup::Configuration::Attributes
      generate_attributes %w(from to smtp)

      def initialize
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
