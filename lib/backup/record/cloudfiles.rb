require 'backup/connection/cloudfiles'

module Backup
  module Record
    class CloudFiles < Backup::Record::Base

      alias_attribute :container, :bucket

      def load_specific_settings(adapter)
        self.container = adapter.procedure.get_storage_configuration.attributes['container']
      end

      private

        def self.destroy_backups(procedure, backups)
          cf = Backup::Connection::CloudFiles.new
          cf.static_initialize(procedure)
          cf.connect
          backups.each do |backup|
            puts "\nDestroying backup \"#{backup.filename}\" from container \"#{backup.container}\"."
            cf.destroy(backup.filename, backup.container)
            backup.destroy
          end
        end

    end
  end
end
