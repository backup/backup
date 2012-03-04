# encoding: utf-8

module Backup
  module Configuration
    module Syncer
      module Cloud
        class Base < Syncer::Base
          class << self

            ##
            # Concurrency setting - defaults to false, but can be set to:
            # - :threads
            # - :processes
            attr_accessor :concurrency_type

            ##
            # Concurrency level - the number of threads or processors to use.
            # Defaults to 2.
            attr_accessor :concurrency_level

          end
        end
      end
    end
  end
end
