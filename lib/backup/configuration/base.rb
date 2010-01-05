module Backup
  module Configuration
    class Base
      extend Backup::Configuration::Attributes
      generate_attributes %w(encrypt_with_password keep_backups notify)
      
      attr_accessor :trigger, :storage_name, :adapter_name

      def initialize(trigger)
        @trigger = trigger
        @adapter_configuration = Backup::Configuration::Adapter.new
        @storage_configuration = Backup::Configuration::Storage.new
      end

      def adapter(adapter, &block)
        @adapter_name = adapter
        @adapter_configuration.instance_eval &block
      end
  
      def storage(storage, &block)
        @storage_name = storage
        @storage_configuration.instance_eval &block
      end
  
      def get_adapter_configuration
        @adapter_configuration
      end
  
      def get_storage_configuration
        @storage_configuration
      end
    end
  end
end
