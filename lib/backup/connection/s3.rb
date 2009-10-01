module Backup
  module Connection
    class S3 < Backup::Connection::Base
      
      def initialize(options = {})
        super(options)
      end
      
      def connect
        AWS::S3::Base.establish_connection!(
          :access_key_id     => options[:s3][:access_key_id], 
          :secret_access_key => options[:s3][:secret_access_key]
        )
      end
      
      def service
        AWS::S3::Service
      end
      
      def bucket
        AWS::S3::Bucket
      end
      
      def object
        AWS::S3::S3Object
      end
      
    end
  end 
end