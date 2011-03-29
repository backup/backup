# encoding: utf-8

module Backup
  module Configuration
    module Notifier
      class Campfire < Base
        class << self

          ##
          # Campfire credentials
          attr_accessor :token, :subdomain, :room_id

        end
      end
    end
  end
end
