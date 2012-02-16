# encoding: utf-8

module Backup
  module Configuration
    module Syncer
      module SCM
        class Base < Syncer::Base
          class << self

            attr_accessor :protocol, :username, :password, :ip, :port, :path, :additional_options

          end
        end
      end
    end
  end
end
