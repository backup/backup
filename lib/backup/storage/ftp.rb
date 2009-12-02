module Backup
  module Storage
    class FTP
      
      attr_accessor :user, :password, :ip, :path, :tmp_path, :final_file
      
      # Stores the file on the remote server using SCP
      def initialize(adapter)
        %w(ip user password path).each do |method|
          send(:"#{method}=", adapter.procedure.get_storage_configuration.attributes[method])
        end
        
        final_file = adapter.final_file
        tmp_path   = adapter.tmp_path
        
        Net::FTP.open(ip, user, password) do |ftp|
          begin ftp.chdir(path)
          rescue; raise "Could not find \"#{path}\" on \"#{ip}\", please ensure this directory exists."; end
          
          begin
            puts "Storing \"#{final_file}\" to path \"#{path}\" on remote server (#{ip})."
            ftp.putbinaryfile(File.join(tmp_path, final_file).gsub('\ ', ' '), File.join(path, final_file))
          rescue; raise "Could not save file to backup server. Is the \"#{path}\" directory writable?"; end
        end
      end
      
    end
  end
end