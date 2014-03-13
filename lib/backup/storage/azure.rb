# encoding: utf-8
require 'azure'

module Backup
  module Storage
    class AzureStore < Base
      class Error < Backup::Error; end

      # Azure credentials
      attr_accessor :storage_account, :storage_access_key

      # Azure Storage Container
      attr_accessor :container_name, :container

      attr_accessor :blob_service

      def initialize(model, storage_id = nil)
        super
        @path ||= 'backups'
        path.sub!(/^\//, '')

        #check_configuration

        Azure.config.storage_account_name = storage_account
        Azure.config.storage_access_key = storage_access_key
        blob_service = Azure::BlobService.new
        container = blob_service.get_container_properties(container_name)
      end

      def transfer!
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = "%s-%s" % [ DateTime.parse(`date`).strftime("%Y-%m-%d-%H-%M-%S"), filename ]
          Logger.info "Storing '#{ container }/#{ dest }'..."
          content = File.open(src, 'rb') { |file| file.read }
          blob_service.create_block_blob(container_name, backup_filename, content)
        end
      end

      def check_configuration
        required = %w{ storage_account, storage_access_key }

        raise Error, <<-EOS if required.map {|name| send(name) }.any?(&:nil?)
          Configuration Error
          #{ required.map {|name| "##{ name }"}.join(', ') } are all required
        EOS
      end
    end
  end
end
