module Backup
  module Connection
    class S3
      
      attr_accessor :adapter, :access_key_id, :secret_access_key, :s3_bucket, :final_file, :tmp_path
      
      # Initializes the S3 connection, setting the values using the S3 adapter
      def initialize(adapter = false)
        if adapter
          self.final_file         = adapter.final_file
          self.tmp_path           = adapter.tmp_path.gsub('\ ', ' ')
          self.access_key_id      = adapter.procedure.get_storage_configuration.attributes['access_key_id']
          self.secret_access_key  = adapter.procedure.get_storage_configuration.attributes['secret_access_key']
          self.s3_bucket          = adapter.procedure.get_storage_configuration.attributes['bucket']
        end
      end
      
      # Sets values from a procedure, rather than from the adapter object
      def static_initialize(procedure)
        self.access_key_id      = procedure.get_storage_configuration.attributes['access_key_id']
        self.secret_access_key  = procedure.get_storage_configuration.attributes['secret_access_key']
        self.s3_bucket          = procedure.get_storage_configuration.attributes['bucket']
      end
      
      # Establishes a connection with Amazon S3 using the credentials provided by the user
      def connect
        AWS::S3::Base.establish_connection!(
          :access_key_id     => access_key_id,
          :secret_access_key => secret_access_key
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
      def store
        puts "Storing \"#{final_file}\" to bucket \"#{s3_bucket}\" on Amazon S3."
        object.store(
          final_file,
          open(File.join(tmp_path, final_file)),
          s3_bucket )
      end
      
      # Destroys file from a bucket on Amazon S3
      def destroy(file, bucket)
        object.delete(
          file,
          bucket )
      end
      
    end
  end 
end