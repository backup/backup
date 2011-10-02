# encoding: utf-8

module Backup
  module Configuration
    module Storage
      class Base < Backup::Configuration::Base
        class << self

          ##
          # Sets the limit to how many backups to keep in the remote location.
          # If the limit exceeds it will remove the oldest backup to make room for the newest
          attr_accessor :keep

          attr_accessor :split_archive_file

          attr_accessor :archive_file_chunk_size

        end
      end
    end
  end
end
