require 'aws/s3'

module Backup
  module Transfer
    class S3 < Backup::Transfer::Base
    
      def initialize(options)
        super(default_options.merge(options))
        
        # Creates a new instance of the Amazon S3 Wrapper Class/Object
        # Passes in the options hash and lets the wrapper extract only the
        # necessary information that is required to establish a link to Amazon S3.
        s3 = Backup::Connection::S3.new(options)
        
        # Connects to Amazon S3 using the credentials provided and
        # stored in the options has by the user
        s3.connect
        
        # Initializes the file transfer to Amazon S3
        s3.transfer
      end
      
      private
      
        # Set default options
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