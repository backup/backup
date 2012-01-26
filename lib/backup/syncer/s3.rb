# encoding: utf-8

##
# Only load the Fog gem when the Backup::Syncer::S3 class is loaded
Backup::Dependency.load('fog')

module Backup
  module Syncer
    class S3 < Cloud
      ##
      # Amazon Simple Storage Service (S3) Credentials
      attr_accessor :access_key_id, :secret_access_key

      ##
      # Region of the specified S3 bucket
      attr_accessor :region

      private

      def connection
        @connection ||= Fog::Storage.new(
          :provider              => 'AWS',
          :aws_access_key_id     => access_key_id,
          :aws_secret_access_key => secret_access_key,
          :region                => region
        )
      end

      def bucket_object
        @bucket_object ||= connection.directories.get(bucket) ||
          connection.directories.create(:key => bucket, :location => region)
      end
    end
  end
end
