# encoding: utf-8
require 'backup/cloud_io/s3'

module Backup
  module Storage
    class S3 < Base
      class Error < Backup::Error; end

      ##
      # Amazon Simple Storage Service (S3) Credentials
      attr_accessor :access_key_id, :secret_access_key, :use_iam_profile

      ##
      # Amazon S3 bucket name
      attr_accessor :bucket

      ##
      # Region of the specified S3 bucket
      attr_accessor :region

      ##
      # Multipart chunk size, specified in MiB.
      #
      # Each package file larger than +chunk_size+
      # will be uploaded using S3 Multipart Upload.
      #
      # Minimum: 5 (but may be disabled with 0)
      # Maximum: 5120
      # Default: 5
      attr_accessor :chunk_size

      ##
      # Number of times to retry failed operations.
      #
      # Default: 10
      attr_accessor :max_retries

      ##
      # Time in seconds to pause before each retry.
      #
      # Default: 30
      attr_accessor :retry_waitsec

      ##
      # Encryption algorithm to use for Amazon Server-Side Encryption
      #
      # Supported values:
      #
      # - :aes256
      #
      # Default: nil
      attr_accessor :encryption

      ##
      # Storage class to use for the S3 objects uploaded
      #
      # Supported values:
      #
      # - :standard (default)
      # - :reduced_redundancy
      #
      # Default: :standard
      attr_accessor :storage_class

      ##
      # Additional options to pass along to fog.
      # e.g. Fog::Storage.new({ :provider => 'AWS' }.merge(fog_options))
      attr_accessor :fog_options

      def initialize(model, storage_id = nil)
        super

        @chunk_size     ||= 5 # MiB
        @max_retries    ||= 10
        @retry_waitsec  ||= 30
        @path           ||= 'backups'
        @storage_class  ||= :standard
        path.sub!(/^\//, '')

        check_configuration
      end

      private

      def cloud_io
        @cloud_io ||= CloudIO::S3.new(
          :access_key_id      => access_key_id,
          :secret_access_key  => secret_access_key,
          :use_iam_profile    => use_iam_profile,
          :region             => region,
          :bucket             => bucket,
          :encryption         => encryption,
          :storage_class      => storage_class,
          :max_retries        => max_retries,
          :retry_waitsec      => retry_waitsec,
          :chunk_size         => chunk_size,
          :fog_options        => fog_options
        )
      end

      def transfer!
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          dest = File.join(remote_path, filename)
          Logger.info "Storing '#{ bucket }/#{ dest }'..."
          cloud_io.upload(src, dest)
        end
      end

      # Called by the Cycler.
      # Any error raised will be logged as a warning.
      def remove!(package)
        Logger.info "Removing backup package dated #{ package.time }..."

        remote_path = remote_path_for(package)
        objects = cloud_io.objects(remote_path)

        raise Error, "Package at '#{ remote_path }' not found" if objects.empty?

        cloud_io.delete(objects)
      end

      def check_configuration
        if use_iam_profile
          required = %w{ bucket }
        else
          required = %w{ access_key_id secret_access_key bucket }
        end
        raise Error, <<-EOS if required.map {|name| send(name) }.any?(&:nil?)
          Configuration Error
          #{ required.map {|name| "##{ name }"}.join(', ') } are all required
        EOS

        raise Error, <<-EOS if chunk_size > 0 && !chunk_size.between?(5, 5120)
          Configuration Error
          #chunk_size must be between 5 and 5120 (or 0 to disable multipart)
        EOS

        raise Error, <<-EOS if encryption && encryption.to_s.upcase != 'AES256'
          Configuration Error
          #encryption must be :aes256 or nil
        EOS

        classes = ['STANDARD', 'REDUCED_REDUNDANCY']
        raise Error, <<-EOS unless classes.include?(storage_class.to_s.upcase)
          Configuration Error
          #storage_class must be :standard or :reduced_redundancy
        EOS
      end

    end
  end
end
