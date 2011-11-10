# encoding: utf-8

module Backup
  module Configuration
    module Syncer
      class InverseRSync < RSync
        class << self

          ##
          # Server credentials
          attr_accessor :username, :password

          ##
          # Server IP Address and SSH port
          attr_accessor :ip

          ##
          # The SSH port to connect to
          attr_accessor :port

          ##
          # Directories to sync
          attr_accessor :directories

          ##
          # Path to sync with
          attr_accessor :remote_path
          
          ##
          # Path to store the synced files/directories to
          attr_accessor :path

          ##
          # Flag for mirroring the files/directories
          attr_accessor :mirror

          ##
          # Flag for compressing (only compresses for the transfer)
          attr_accessor :compress

          ##
          # Additional options for the rsync cli
          attr_accessor :additional_options

        end
      end
    end
  end
end
