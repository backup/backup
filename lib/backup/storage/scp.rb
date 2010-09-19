require 'net/scp'

module Backup
  module Storage
    class SCP < Base
      
      attr_accessor :user, :password, :ip, :path, :tmp_path, :final_file
      
      # Stores the backup file on the remote server using SCP
      def initialize(adapter)
        %w(ip user password path).each do |method|
          send("#{method}=", adapter.procedure.get_storage_configuration.attributes[method])
        end
        
        final_file = adapter.final_file
        tmp_path   = adapter.tmp_path
        
        Net::SSH.start(ip, user, :password => password) do |ssh|
          ssh.exec "mkdir -p #{path}"
        end
        
        puts "Storing \"#{final_file}\" to path \"#{path}\" on remote server (#{ip})."
        Net::SCP.start(ip, user, :password => password) do |scp|
          scp.upload! File.join(tmp_path, final_file).gsub('\ ', ' '), path
        end
      end
      
    end
  end
end
