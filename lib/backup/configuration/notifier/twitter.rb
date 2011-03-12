# encoding: utf-8

module Backup
  module Configuration
    module Notifier
      class Twitter < Base
        class << self

          ##
          # Twitter consumer key credentials
          attr_accessor :consumer_key, :consumer_secret

          ##
          # OAuth credentials
          attr_accessor :oauth_token, :oauth_token_secret

        end
      end
    end
  end
end
