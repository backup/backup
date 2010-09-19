require "aws/s3"

module Backup
  module Connection
    class S3
      include Backup::CommandHelper
      
      # I'm not sure if this size limit is inclusive or exclusive...so playing it safe
      MAX_S3_FILE_SIZE = 5368709120 - 1
      
      attr_accessor :adapter, :procedure, :access_key_id, :secret_access_key, :s3_bucket, :use_ssl, :final_file, :tmp_path
      
      # Initializes the S3 connection, setting the values using the S3 adapter
      def initialize(adapter = false)
        if adapter
          self.adapter            = adapter
          self.procedure          = adapter.procedure
          self.final_file         = adapter.final_file
          self.tmp_path           = adapter.tmp_path.gsub('\ ', ' ')
          load_storage_configuration_attributes
        end
        self.connect
      end
      
      # Sets values from a procedure, rather than from the adapter object
      def static_initialize(procedure)
        self.procedure = procedure
        load_storage_configuration_attributes(true)
        self.connect
      end
      
      # Establishes a connection with Amazon S3 using the credentials provided by the user
      def connect
        ::AWS::S3::Base.establish_connection!(
          :access_key_id     => access_key_id, 
          :secret_access_key => secret_access_key,
          :use_ssl => use_ssl
        )
      end

      # Initializes the file transfer to Amazon S3
      # This can only run after a connection has been made using the #connect method 
      def store
        #TODO: need to add logic like this to restore: `cat /mnt/dvd/part.xxx >>restore.tgz`
        tmp_file_path = File.join(tmp_path, final_file)
        store_files = []
        if File.stat(File.join(tmp_path, final_file)).size >= MAX_S3_FILE_SIZE
          #we need to split!
          `split -b #{MAX_S3_FILE_SIZE}  #{tmp_file_path} #{tmp_file_path}.`
          store_files += `ls  #{tmp_file_path}.*`.split
          log("Splitting '#{final_file}' into #{store_files.length} parts as it is too large for s3.")
        else
          store_files << tmp_file_path
        end

        #lets make sure it exists
        ::AWS::S3::Bucket.create(s3_bucket)
        
        store_files.each do |tmp_file|
          file_name = File.basename(tmp_file)
          log("Saving '#{file_name}' to s3 bucket '#{s3_bucket}'")
          AWS::S3::S3Object.store(file_name, open(tmp_file), s3_bucket)
        end
      end

      # Destroys file from a bucket on Amazon S3
      def destroy(file, bucket_as_string)
        ::AWS::S3::Bucket.create(s3_bucket)
        ::AWS::S3::S3Object.delete(file, s3_bucket)
      end

      private

        def load_storage_configuration_attributes(static = false)          
          %w(access_key_id secret_access_key use_ssl).each do |attribute|
            if static
              send("#{attribute}=", procedure.get_storage_configuration.attributes[attribute])
            else
              send("#{attribute}=", adapter.procedure.get_storage_configuration.attributes[attribute])
            end
          end
          
          if static
            self.s3_bucket = procedure.get_storage_configuration.attributes['bucket']
          else
            self.s3_bucket = adapter.procedure.get_storage_configuration.attributes['bucket']
          end
        end
        
    end
  end 
end
