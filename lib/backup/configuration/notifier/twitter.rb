# encoding: utf-8

module Backup
  module Configuration
    module Notifier
      class Twitter < Base
        class << self

          ##
          # Twitter API credentials
          attr_accessor :consumer_key, :consumer_secret
          attr_accessor :oauth_token, :oauth_token_secret

        end
      end
    end
  end
end
