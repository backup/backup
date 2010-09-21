module Backup
  module Configuration
    class Adapter
      extend Backup::Configuration::Attributes
      generate_attributes %w(files exclude user password database tables skip_tables commands additional_options backup_method)

      def initialize
        @options = Backup::Configuration::AdapterOptions.new
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
