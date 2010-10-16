module Backup
  module Configuration
    class Base
      extend Backup::Configuration::Attributes
      generate_attributes %w(encrypt_with_password encrypt_with_gpg_public_key keep_backups notify)
      
      attr_accessor :trigger, :storage_name, :adapter_name, :before_backup_block, :after_backup_block

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

      def before_backup(&block)
        @before_backup_block = block
      end

      def after_backup(&block)
        @after_backup_block = block
      end

      def storage_class
        case @storage_name.to_sym
          when :cloudfiles then Backup::Storage::CloudFiles
          when :s3         then Backup::Storage::S3
          when :scp        then Backup::Storage::SCP
          when :ftp        then Backup::Storage::FTP
          when :sftp       then Backup::Storage::SFTP
          when :local      then Backup::Storage::Local
          when :dropbox    then Backup::Storage::Dropbox
        end
      end

      def record_class
        case @storage_name.to_sym
          when :cloudfiles then Backup::Record::CloudFiles
          when :s3         then Backup::Record::S3
          when :scp        then Backup::Record::SCP
          when :ftp        then Backup::Record::FTP
          when :sftp       then Backup::Record::SFTP
          when :local      then Backup::Record::Local
          when :dropbox    then Backup::Record::Dropbox
        end        
      end

      # Initializes the storing process depending on the store settings
      def initialize_storage(adapter)
        storage_class.new(adapter)
      end

      def initialize_record
        record_class.new
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
