# encoding: utf-8

module Backup
  module Configuration
    module Notifier
      class Sendmail < Base
        class << self

          ##
          # Sender and Receiver email addresses
          # Examples:
          #  sender   - my.email.address@gmail.com
          #  receiver - your.email.address@gmail.com
          attr_accessor :from, :to

        end
      end
    end
  end
end
