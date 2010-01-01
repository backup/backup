module Backup
  module Configuration
    class Base
      attr_accessor :attributes, :trigger, :storage_name, :adapter_name

      %w(encrypt_with_password keep_backups notify).each do |method|
        define_method method do |value|
          attributes[method] = value
        end
      end

      def initialize(trigger)
        @attributes = {}
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