require 'net/sftp'

module Backup
  module Record
    class SFTP < Backup::Record::Base

      attr_accessor :ip, :user, :password
      
      def load_specific_settings(adapter)
        %w(ip user password path).each do |method|
          send(:"#{method}=", adapter.procedure.get_storage_configuration.attributes[method])
        end
      end
      
      private
        
        def self.destroy_backups(procedure, backups)
          ip        = procedure.get_storage_configuration.attributes['ip']
          user      = procedure.get_storage_configuration.attributes['user']
          password  = procedure.get_storage_configuration.attributes['password']
          
          Net::SFTP.start(ip, user, :password => password) do |sftp|
            backups.each do |backup|
              puts "\nDestroying backup \"#{backup.filename}\" from path \"#{backup.path}\"."
              begin
                sftp.remove!(File.join(backup.path, backup.filename))
                backup.destroy
              rescue
                puts "Could not find backup #{backup.path}/#{backup.filename}.."
                backup.destroy
              end
            end
          end
        end
        
    end
  end
end
