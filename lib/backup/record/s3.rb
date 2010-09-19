require 'backup/connection/s3'

module Backup
  module Record
    class S3 < Backup::Record::Base
      
      def load_specific_settings(adapter)
        self.bucket = adapter.procedure.get_storage_configuration.attributes['bucket']
      end
      
      private
        
        def self.destroy_backups(procedure, backups)
          s3 = Backup::Connection::S3.new
          s3.static_initialize(procedure)
          backups.each do |backup|
            puts "\nDestroying backup \"#{backup.filename}\" from bucket \"#{backup.bucket}\"."
            s3.destroy(backup.filename, backup.bucket)
            backup.destroy
          end
        end
        
    end
  end
end
