# encoding: utf-8

##
# Only load the Mail gem and Erb library when using Mail notifications
Backup::Dependency.load('mail')

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
      # Notify the user of the backup operation results.
      # `status` indicates one of the following:
      #
      # `:success`
      # : The backup completed successfully.
      # : Notification will be sent if `on_success` was set to `true`
      #
      # `:warning`
      # : The backup completed successfully, but warnings were logged
      # : Notification will be sent, including a copy of the current
      # : backup log, if `on_warning` was set to `true`
      #
      # `:failure`
      # : The backup operation failed.
      # : Notification will be sent, including the Exception which caused
      # : the failure, the Exception's backtrace, a copy of the current
      # : backup log and other information if `on_failure` was set to `true`
      #
      def notify!(status)
        name = case status
               when :success then 'Success'
               when :warning then 'Warning'
               when :failure then 'Failure'
               end
        mail[:subject] = "[Backup::%s] #{model.label} (#{model.trigger})" % name
        mail[:body]    = template.result('notifier/mail/%s.erb' % status.to_s)
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
