# encoding: utf-8

module Backup
  module Configuration
    module Storage
      class Local < Base
        class << self

          ##
          # Path to store backups to
          attr_accessor :path

        end
      end
    end
  end
end
