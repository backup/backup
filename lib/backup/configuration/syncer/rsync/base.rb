# encoding: utf-8

module Backup
  module Configuration
    module Syncer
      module RSync
        class Base < Syncer::Base
          class << self

            ##
            # Path to store the synced files/directories to
            attr_accessor :path

            ##
            # Flag for mirroring the files/directories
            attr_accessor :mirror

            ##
            # Additional options for the rsync cli
            attr_accessor :additional_options

          end
        end
      end
    end
  end
end

