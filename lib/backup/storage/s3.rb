# encoding: utf-8

Backup::Dependency.load('fog')

module Backup
  module Storage
    class S3 < Base

      ##
      # Amazon Simple Storage Service (S3) Credentials
      attr_accessor :access_key_id, :secret_access_key

      ##
      # Amazon S3 bucket name
      attr_accessor :bucket

      ##
      # Region of the specified S3 bucket
      attr_accessor :region

      def initialize(model, storage_id = nil, &block)
        super
        instance_eval(&block) if block_given?

        @path ||= 'backups'
        path.sub!(/^\//, '')
      end

      private

      def connection
        @connection ||= begin
          conn = Fog::Storage.new(
            :provider               => 'AWS',
            :aws_access_key_id      => access_key_id,
            :aws_secret_access_key  => secret_access_key,
            :region                 => region
          )
          conn.sync_clock
          conn
        end
      end

      def transfer!
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = File.join(remote_path, filename)
          Logger.info "Storing '#{ bucket }/#{ dest }'..."
          File.open(src, 'r') do |file|
            connection.put_object(bucket, dest, file)
          end
        end
      end

      # Called by the Cycler.
      # Any error raised will be logged as a warning.
      def remove!(package)
        Logger.info "Removing backup package dated #{ package.time }..."

        remote_path = remote_path_for(package)
        package.filenames.each do |filename|
          target = File.join(remote_path, filename)
          connection.delete_object(bucket, target)
        end
      end

    end
  end
end
