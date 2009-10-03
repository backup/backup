require 'aws/s3'

module Backup
  module Transfer
    class S3 < Backup::Transfer::Base
    
      def initialize(options)
        super(default_options.merge(options))
        
        s3 = Backup::Connection::S3.new(options)
        s3.connect
        s3.transfer
      end
      
      private
      
        def default_options
          {:s3 => {
              :access_key_id      => '',
              :secret_access_key  => '',
              :bucket             => ''
            }}
        end
      
    end
  end
end