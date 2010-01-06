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

      def initialize_storage(adapter)
        case @storage_name.to_sym
          when :s3    then Backup::Storage::S3.new(adapter)
          when :scp   then Backup::Storage::SCP.new(adapter)
          when :ftp   then Backup::Storage::FTP.new(adapter)
          when :sftp  then Backup::Storage::SFTP.new(adapter)
          when :local then Backup::Storage::Local.new(adapter)
        end
      end

      def initialize_record
        case @storage_name.to_sym
          when :s3    then Backup::Record::S3.new
          when :scp   then Backup::Record::SCP.new
          when :ftp   then Backup::Record::FTP.new
          when :sftp  then Backup::Record::SFTP.new
          when :local then Backup::Record::Local.new
        end        
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
