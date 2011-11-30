# encoding: utf-8

##
# Only load the Mail gem and Erb library when using Mail notifications
Backup::Dependency.load('mail')
require 'erb'

module Backup
  module Notifier
    class Mail < Base

      ##
      # Container for the Mail object
      attr_accessor :mail

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
      # Performs the notification
      # Extends from super class. Must call super(model, exception).
      # If any pre-configuration needs to be done, put it above the super(model, exception)
      def perform!(model, exception = false)
        super(model, exception)
      end

    private

      ##
      # Sends an email informing the user that the backup operation
      # proceeded without any errors
      def notify_success!
        mail[:subject] = "[Backup::Succeeded] #{model.label} (#{model.trigger})"
        mail[:body]    = template.result('notifier/mail/success') # @model needs to be avail
        mail.deliver!
      end

      ##
      # Sends an email informing the user that the backup operation
      # raised an exception and will send the user the error details
      def notify_failure!
        mail[:subject] = "[Backup::Failed] #{model.label} (#{model.trigger})"
        mail[:body]    = template.result('notifier/mail/failure') # @model, @exception need to be avail
        mail.deliver!
      end

      ##
      # Configures the Mail gem by setting the defaults.
      # Instantiates the @mail object with the @to and @from attributes
      def set_defaults!
        defaults = {
          :address              => @address,
          :port                 => @port,
          :domain               => @domain,
          :user_name            => @user_name,
          :password             => @password,
          :authentication       => @authentication,
          :enable_starttls_auto => @enable_starttls_auto,
          :openssl_verify_mode  => @openssl_verify_mode
        }

        ::Mail.defaults do
          delivery_method :smtp, defaults
        end

        @mail        = ::Mail.new
        @mail[:from] = @from
        @mail[:to]   = @to
      end

    end
  end
end
