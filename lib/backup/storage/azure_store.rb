# encoding: utf-8
require 'azure'

module Backup
  module Storage
    class AzureStore < Base
      include Storage::Cycler
      class Error < Backup::Error; end

      # Azure credentials
      attr_accessor :storage_account, :storage_access_key

      # Azure Storage Container
      attr_accessor :container_name, :container
      attr_accessor :blob_service, :chunk_size

      def initialize(model, storage_id = nil)
        super
        @path       ||= 'backups'
        @chunk_size ||= 1024 * 1024 * 4 # bytes
        path.sub!(/^\//, '')

        #check_configuration

        Azure.config.storage_account_name = storage_account
        Azure.config.storage_access_key = storage_access_key
      end

      def azure_blob_service
        @blob_service ||= Azure::Blob::BlobService.new
      end

      def azure_container
        @azure_container ||= azure_blob_service.get_container_properties(container_name)
      end

      def transfer!
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = File.join(remote_path, filename)
          Logger.info "Creating Block Blob '#{ azure_container.name }/#{ dest }'..."
          blob = blob_service.create_block_blob(@azure_container.name, dest, "")
          chunk_ids = []

          File.open(src, "r") do |fh_in|
            until fh_in.eof?
              chunk = "#{"%05d"%(fh_in.pos/chunk_size)}"
              Logger.info "Storing blob '#{ blob.name }/#{ chunk }'..."
              azure_blob_service.create_blob_block(azure_container.name, blob.name, chunk, fh_in.read(chunk_size))
              chunk_ids.push([chunk])
            end
          end
          azure_blob_service.commit_blob_blocks(azure_container.name, blob.name, chunk_ids)
        end
      end

      # Called by the Cycler.
      # Any error raised will be logged as a warning.
      def remove!(package)
        Logger.info "Removing backup package dated #{package.time}..."

        package.filenames.each do |filename|
          azure_blob_service.delete_blob(azure_container.name, "#{remote_path_for(package)}/#{filename}")
        end
      end

      def check_configuration
        required = %w(storage_account storage_access_key)

        raise Error, <<-EOS if required.map {|name| send(name) }.any?(&:nil?)
          Configuration Error
          #{ required.map {|name| "##{ name }"}.join(', ') } are all required
        EOS
      end
    end
  end
end