require 'backup/connection/s3'

module Backup
  module Storage
    class S3 < Base
      
      # Stores the backup file on the remote server using S3
      def initialize(adapter)
        s3 = Backup::Connection::S3.new(adapter)
        s3.store
      end
      
    end
  end
end
