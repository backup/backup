# encoding: utf-8

module Backup
  module Configuration
    module Notifier
      class Presently < Base
        class << self

          ##
          # Presently subdomain
          attr_accessor :subdomain

          ##
          # Presently credentials
          attr_accessor :user_name, :password

          ##
          # Group id
          attr_accessor :group_id

        end
      end
    end
  end
end
