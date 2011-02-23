# encoding: utf-8

module Backup
  module Notifier
    module Configuration
      class Mail < Base
        class << self

          ##
          # Sender and Receiver email addresses
          # Examples:
          #  sender   - my.email.address@gmail.com
          #  receiver - your.email.address@gmail.com
          attr_accessor :from, :to

          ##
          # The address to use
          # Example: smtp.gmail.com
          attr_accessor :address

          ##
          # The port to connect to
          # Example: 587
          attr_accessor :port

          ##
          # Your domain (if applicable)
          # Example: mydomain.com
          attr_accessor :domain

          ##
          # Username and Password (sender email's credentials)
          # Examples:
          #  user_name - meskyanichi
          #  password  - my_secret_password
          attr_accessor :user_name, :password

          ##
          # Authentication type
          # Example: plain
          attr_accessor :authentication

          ##
          # Automatically set TLS
          # Example: true
          attr_accessor :enable_starttls_auto

        end
      end
    end
  end
end
