# encoding: utf-8

module Backup
  module Configuration
    module Notifier
      class Mail < Base
        class << self

          ##
          # Mail delivery method to be used by the Mail gem.
          # Supported methods:
          #
          # `:smtp` [::Mail::SMTP] (default)
          # : Settings used only by this method:
          # : `address`, `port`, `domain`, `user_name`, `password`
          # : `authentication`, `enable_starttls_auto`, `openssl_verify_mode`
          #
          # `:sendmail` [::Mail::Sendmail]
          # : Settings used only by this method:
          # : `sendmail`, `sendmail_args`
          #
          # `:file` [::Mail::FileDelivery]
          # : Settings used only by this method:
          # : `mail_folder`
          #
          attr_accessor :delivery_method

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

          ##
          # OpenSSL Verify Mode
          # Example: none - Only use this option for a self-signed and/or wildcard certificate
          attr_accessor :openssl_verify_mode

          ##
          # When using the `:sendmail` `delivery_method` option,
          # this may be used to specify the absolute path to `sendmail` (if needed)
          # Example: '/usr/sbin/sendmail'
          attr_accessor :sendmail

          ##
          # Optional arguments to pass to `sendmail`
          # Note that this will override the defaults set by the Mail gem (currently: '-i -t')
          # So, if set here, be sure to set all the arguments you require.
          # Example: '-i -t -X/tmp/traffic.log'
          attr_accessor :sendmail_args

          ##
          # Folder where mail will be kept when using the `:file` `delivery_method` option.
          # Default location is '$HOME/backup-mails'
          # Example: '/tmp/test-mails'
          attr_accessor :mail_folder

        end
      end
    end
  end
end
