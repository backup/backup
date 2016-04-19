# encoding: utf-8
require 'qiniu'

module Backup
  module Storage
    class Qiniu < Base
      include Storage::Cycler
      class Error < Backup::Error; end

      ##
      # Qiniu API credentials
      attr_accessor :access_key, :secret_key

      ##
      # Qiniu bucket name
      attr_accessor :bucket

      def initialize(model, storage_id = nil)
        super

        @path ||= 'backups'

        check_configuration
        config_credentials
      end

      private
      def transfer!
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = File.join(remote_path, filename)
          Logger.info "Storing '#{ dest }'..."

          ::Qiniu.upload_file(uptoken: ::Qiniu.generate_upload_token,
                              bucket: bucket,
                              file: src,
                              key: dest)
        end
      end

      # Called by the Cycler.
      # Any error raised will be logged as a warning.
      def remove!(package)
        Logger.info "Removing backup package dated #{ package.time }..."
        remote_path = remote_path_for(package)
        package.filenames.each do |filename|
          ::Qiniu.delete(bucket, File.join(remote_path, filename))
        end
      end

      def check_configuration
         required = %w{ access_key secret_key bucket }

        raise Error, <<-EOS if required.map {|name| send(name) }.any?(&:nil?)
          Configuration Error
          #{ required.map {|name| "##{ name }"}.join(', ') } are all required
        EOS
      end

      def config_credentials
        ::Qiniu.establish_connection!(access_key: access_key, secret_key: secret_key)
      end
    end
  end
end
