# encoding: utf-8

##
# Only load the Fog gem when the Backup::Storage::S3 class is loaded
require 'mail'

module Backup
  module Notifier
    class Mail < Base

      ##
      # Container for the Mail object
      attr_accessor :mail

      ##
      # Container for the Model object
      attr_accessor :model

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
      # Instantiates a new Backup::Notifier::Mail object
      def initialize(&block)
        load_defaults!
        instance_eval(&block) if block_given?
        set_defaults!
      end

      ##
      # Performs the notification
      # Takes an exception object that might've been created if an exception occurred.
      # If this is the case it'll invoke notify_failure!(exception), otherwise, if no
      # error was raised, it'll go ahead and notify_success!
      #
      # If'll only perform these if on_success is true or on_failure is true
      def perform!(model, exception = false)
        @model = model

        if exception.eql?(false)
          notify_success! if on_success
        else
          notify_failure!(exception) if on_failure
        end
      end

    private

      ##
      # Sends an email informing the user that the backup operation
      # proceeded without any errors
      def notify_success!
        mail[:subject] = "[Backup::Succeeded] #{model.label} (#{model.trigger})"
        mail[:body]    = "Backup \"#{model.label}\" (#{model.trigger}) finished without any errors." +
                         "\n\nhttps://github.com/meskyanichi/backup"
        mail.deliver!
      end

      ##
      # Sends an email informing the user that the backup operation
      # raised an exception and will send the user the error details
      def notify_failure!(exception)
        mail[:subject] = "[Backup::Failed] #{model.label} (#{model.trigger})"
        mail[:body]    = "There seemed to be a problem backing up \"#{model.label}\" (#{model.trigger}).\n\n" +
                         ("=" * 75) + "\n\nException that got raised: " + exception + "\nBacktrace of the exception below\n\n" + ("=" * 75) +
                         "\n\n" + exception.backtrace.join("\n") + "\n\n" + ("=" * 75) + "\n\nhttps://github.com/meskyanichi/backup"
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
          :enable_starttls_auto => @enable_starttls_auto
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
