module Backup
  module Transfer
    class SSH < Backup::Transfer::Base
      
      def initialize(options)
        super(default_options.merge(options))
        
        ssh = Backup::Connection::SSH.new(options)
        ssh.store
                              
        remove_temp_files
      end
      
      
      private
      
        def default_options
          {:ssh => {
            :user => "root",
            :ip   => "123.45.678.90",
            :path => "/var/backups/"
          }}
        end
      
    end
  end
end