module Backup
  module Transfer
    class SSH < Backup::Transfer::Base
      
      def initialize(options)
        super(default_options.merge(options))
        
        # Creates a new instance of the SSH Wrapper Class/Object
        # Passes in the options hash and lets the wrapper extract only the
        # necessary information that is required to later transfer the specified file through SSH.
        ssh = Backup::Connection::SSH.new(options)
        
        # Initializes the file transfer to the specified server through SSH.
        ssh.transfer
      end
      
      private
      
        # Set default options
        def default_options
          {:ssh => {
            :user => "",
            :ip   => "",
            :path => "/var/backups/"
          }}
        end

    end
  end
end