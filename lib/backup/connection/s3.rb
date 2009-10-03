module Backup
  module Connection
    class S3 < Backup::Connection::Base
      
      def initialize(options = {})
        super(options)
      end
      
      # Establishes a connection with Amazon S3 using the credentials provided by the user
      def connect
        AWS::S3::Base.establish_connection!(
          :access_key_id     => options[:s3][:access_key_id], 
          :secret_access_key => options[:s3][:secret_access_key]
        )
      end
      
      # Wrapper for the Service object
      def service
        AWS::S3::Service
      end
      
      # Wrapper for the Bucket object
      def bucket
        AWS::S3::Bucket
      end
      
      # Wrapper for the Object object
      def object
        AWS::S3::S3Object
      end
      
      # Initializes the file transfer to Amazon S3
      # This can only run after a connection has been made using the #connect method 
      def transfer
        object.store(
          options[:backup_file],
          open(File.join(options[:backup_path], options[:backup_file])),
          options[:s3][:bucket] )
      end
      
    end
  end 
end