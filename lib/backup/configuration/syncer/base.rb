# encoding: utf-8

module Backup
  module Configuration
    module Syncer
      class Base < Configuration::Base
        class << self

          ##
          # Path to store the synced files/directories to
          attr_accessor :path

          ##
          # Flag for mirroring the files/directories
          attr_accessor :mirror

        end
      end
    end
  end
end

