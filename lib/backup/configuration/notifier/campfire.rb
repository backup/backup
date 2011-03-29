# encoding: utf-8

module Backup
  module Configuration
    module Notifier
      class Campfire < Base
        class << self

          ##
          # Campfire api authentication token
          attr_accessor :token

          ##
          # Campfire account's subdomain
          attr_accessor :subdomain

          ##
          # Campfire account's room id
          attr_accessor :room_id

        end
      end
    end
  end
end
