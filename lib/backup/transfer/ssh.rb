module Backup
  module Transfer
    class SSH < Backup::Transfer::Base
      
      def initialize(options)
        super(default_options.merge(options))
        
        ssh = Backup::Connection::SSH.new(options)
        ssh.transfer
      end
      
      private
      
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