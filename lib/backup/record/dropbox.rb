require 'backup/connection/dropbox'

module Backup
  module Record
    class Dropbox < Backup::Record::Base
      def load_specific_settings(adapter)
      end

      private

      def self.destroy_backups(procedure, backups)
        dropbox = Backup::Connection::Dropbox.new
        dropbox.static_initialize(procedure)
        session = dropbox.session
        backups.each do |backup|
          puts "\nDestroying backup \"#{backup.filename}\"."
          path_to_file = File.join(dropbox.path, backup.filename)
          begin
            session.delete(path_to_file, :mode => :dropbox)
          rescue ::Dropbox::FileNotFoundError => e
            puts "\n Backup with name '#{backup.filename}' was not found in '#{dropbox.path}'"
          end
        end
      end
    end
  end
end
