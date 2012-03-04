# encoding: utf-8

module Backup
  module Configuration
    module Syncer
      module RSync
        class Base < Syncer::Base
          class << self

            ##
            # Additional options for the rsync cli
            attr_accessor :additional_options

          end
        end
      end
    end
  end
end

