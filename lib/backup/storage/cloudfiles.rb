require 'backup/connection/cloudfiles'

module Backup
  module Storage
    class CloudFiles < Base

      # Stores the backup file on the remote server using Rackspace Cloud Files
      def initialize(adapter)
        cf = Backup::Connection::CloudFiles.new(adapter)
        cf.connect
        cf.store
      end

    end
  end
end
