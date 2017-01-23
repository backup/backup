require 'aliyun/oss'

module Backup
  module Storage
    class AliyunOss < Base
      include Storage::Cycler
      class Error < Backup::Error; end

      ##
      # Aliyun OSS API credentials
      attr_accessor :access_key, :secret_key

      ##
      # Aliyun OSS bucket name
      attr_accessor :bucket

      ##
      # Aliyun OSS endpoint
      attr_accessor :endpoint

      def initialize(model, storage_id = nil)
        super

        @path ||= "backups"

        check_configuration
      end

      private

      def transfer!
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = File.join(remote_path, filename)
          Logger.info "Storing '#{dest}'..."

          bucket_client = client.get_bucket(bucket)
          bucket_client.put_object(dest, file: src)
        end
      end

      # Called by the Cycler.
      # Any error raised will be logged as a warning.
      def remove!(package)
        Logger.info "Removing backup package dated #{package.time}..."
        remote_path = remote_path_for(package)
        package.filenames.each do |filename|
          bucket_client = client.get_bucket(bucket)
          bucket_client.delete_object(File.join(remote_path, filename))
        end
      end

      def check_configuration
        required = %w(access_key secret_key bucket endpoint)

        raise Error, <<-EOS if required.map { |name| send(name) }.any?(&:nil?)
          Configuration Error
          #{required.map { |name| "##{name}" }.join(", ")} are all required
        EOS
      end

      def client
        return @client if @client

        @client =  Aliyun::OSS::Client.new(
          endpoint: endpoint,
          access_key_id: access_key,
          access_key_secret: secret_key,
        )
      end
    end
  end
end
