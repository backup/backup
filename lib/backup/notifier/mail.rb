# encoding: utf-8
require 'mail'

module Backup
  module Notifier
    class Mail < Base

      ##
      # Mail delivery method to be used by the Mail gem.
      #
      # Supported methods:
      #
      # [:smtp - ::Mail::SMTP (default)]
      #   Settings used by this method:
      #   {#address}, {#port}, {#domain}, {#user_name}, {#password},
      #   {#authentication}, {#encryption}, {#openssl_verify_mode}
      #
      # [:sendmail - ::Mail::Sendmail]
      #   Settings used by this method:
      #   {#sendmail_args}
      #
      # [:exim - ::Mail::Exim]
      #   Settings used by this method:
      #   {#exim_args}
      #
      # [:file - ::Mail::FileDelivery]
      #   Settings used by this method:
      #   {#mail_folder}
      #
      attr_accessor :delivery_method

      ##
      # Sender Email Address
      attr_accessor :from

      ##
      # Receiver Email Address
      attr_accessor :to

      ##
      # SMTP Server Address
      attr_accessor :address

      ##
      # SMTP Server Port
      attr_accessor :port

      ##
      # Your domain (if applicable)
      attr_accessor :domain

      ##
      # SMTP Server Username (sender email's credentials)
      attr_accessor :user_name

      ##
      # SMTP Server Password (sender email's credentials)
      attr_accessor :password

      ##
      # Authentication type
      #
      # Acceptable values: +:plain+, +:login+, +:cram_md5+
      attr_accessor :authentication

      ##
      # Set the method of encryption to be used for the +SMTP+ connection.
      #
      # [:none (default)]
      #   No encryption will be used.
      #
      # [:starttls]
      #   Use +STARTTLS+ to upgrade the connection to a +SSL/TLS+ connection.
      #
      # [:tls or :ssl]
      #   Use a +SSL/TLS+ connection.
      attr_accessor :encryption

      ##
      # OpenSSL Verify Mode
      #
      # Valid modes: +:none+, +:peer+, +:client_once+, +:fail_if_no_peer_cert+
      # See +OpenSSL::SSL+ for details.
      #
      # Use +:none+ for a self-signed and/or wildcard certificate
      attr_accessor :openssl_verify_mode

      ##
      # Optional arguments to pass to `sendmail`
      #
      # Note that this will override the defaults set by the Mail gem
      # (currently: '-i'). So, if set here, be sure to set all the arguments
      # you require.
      #
      # Example: '-i -X/tmp/traffic.log'
      attr_accessor :sendmail_args

      ##
      # Optional arguments to pass to `exim`
      #
      # Note that this will override the defaults set by the Mail gem
      # (currently: '-i -t') So, if set here, be sure to set all the arguments
      # you require.
      #
      # Example: '-i -t -X/tmp/traffic.log'
      attr_accessor :exim_args

      ##
      # Folder where mail will be kept when using the `:file` `delivery_method`.
      #
      # Default location is '$HOME/Backup/emails'
      attr_accessor :mail_folder

      ##
      # Array of statuses for which the log file should be attached.
      #
      # Available statuses are: `:success`, `:warning` and `:failure`.
      # Default: [:warning, :failure]
      attr_accessor :send_log_on

      def initialize(model, &block)
        super
        instance_eval(&block) if block_given?

        @send_log_on ||= [:warning, :failure]
      end

      private

      ##
      # Notify the user of the backup operation results.
      #
      # `status` indicates one of the following:
      #
      # `:success`
      # : The backup completed successfully.
      # : Notification will be sent if `on_success` is `true`.
      #
      # `:warning`
      # : The backup completed successfully, but warnings were logged.
      # : Notification will be sent, including a copy of the current
      # : backup log, if `on_warning` or `on_success` is `true`.
      #
      # `:failure`
      # : The backup operation failed.
      # : Notification will be sent, including a copy of the current
      # : backup log, if `on_failure` is `true`.
      #
      def notify!(status)
        tag = case status
              when :success then '[Backup::Success]'
              when :warning then '[Backup::Warning]'
              when :failure then '[Backup::Failure]'
              end

        email = new_email
        email.subject = "#{ tag } #{ model.label } (#{ model.trigger })"

        send_log = send_log_on.include?(status)
        template = Backup::Template.new({ :model => model, :send_log => send_log })
        email.body = template.result('notifier/mail/%s.erb' % status.to_s)

        if send_log
          email.convert_to_multipart
          email.attachments["#{ model.time }.#{ model.trigger }.log"] = {
            :mime_type => 'text/plain;',
            :content   => Logger.messages.map(&:formatted_lines).flatten.join("\n")
          }
        end

        email.deliver! # raise error if unsuccessful
      end

      ##
      # Configures the Mail gem by setting the defaults.
      # Creates and returns a new email, based on the @delivery_method used.
      def new_email
        method = %w{ smtp sendmail exim file test }.
            index(@delivery_method.to_s) ? @delivery_method.to_s : 'smtp'

        options =
            case method
            when 'smtp'
              { :address              => @address,
                :port                 => @port,
                :domain               => @domain,
                :user_name            => @user_name,
                :password             => @password,
                :authentication       => @authentication,
                :enable_starttls_auto => @encryption == :starttls,
                :openssl_verify_mode  => @openssl_verify_mode,
                :ssl                  => @encryption == :ssl,
                :tls                  => @encryption == :tls
              }
            when 'sendmail'
              opts = {}
              opts.merge!(:location  => utility(:sendmail))
              opts.merge!(:arguments => @sendmail_args) if @sendmail_args
              opts
            when 'exim'
              opts = {}
              opts.merge!(:location  => utility(:exim))
              opts.merge!(:arguments => @exim_args) if @exim_args
              opts
            when 'file'
              @mail_folder ||= File.join(Config.root_path, 'emails')
              { :location => File.expand_path(@mail_folder) }
            when 'test' then {}
            end

        ::Mail.defaults do
          delivery_method method.to_sym, options
        end

        email = ::Mail.new
        email.to   = @to
        email.from = @from
        email
      end

      attr_deprecate :enable_starttls_auto, :version => '3.2.0',
                     :message => "Use #encryption instead.\n" +
                        'e.g. mail.encryption = :starttls',
                     :action => lambda {|klass, val|
                       klass.encryption = val ? :starttls : :none
                     }

      attr_deprecate :sendmail, :version => '3.6.0',
          :message => 'Use Backup::Utilities.configure instead.',
          :action => lambda {|klass, val|
            Utilities.configure { sendmail val }
          }

      attr_deprecate :exim, :version => '3.6.0',
          :message => 'Use Backup::Utilities.configure instead.',
          :action => lambda {|klass, val|
            Utilities.configure { exim val }
          }

    end
  end
end

# Patch mail v2.5.4 Exim delivery method
# https://github.com/meskyanichi/backup/issues/446
# https://github.com/mikel/mail/pull/546
module Mail
  class Exim
    def self.call(path, arguments, destinations, encoded_message)
      popen "#{path} #{arguments}" do |io|
        io.puts encoded_message.to_lf
        io.flush
      end
    end
  end
end

# Patch mail v2.5.4 for ruby-1.8.7
# https://github.com/mikel/mail/issues/548
# https://github.com/mikel/mail/commit/c7318a6c03c1ecb3f574ccd2e3f06778687d1d15
if RUBY_VERSION < '1.9'
  module Mail
    class SMTP
      private
      def ssl_context
        openssl_verify_mode = settings[:openssl_verify_mode]

        if openssl_verify_mode.kind_of?(String)
          openssl_verify_mode = "OpenSSL::SSL::VERIFY_#{openssl_verify_mode.upcase}".constantize
        end

        context = Net::SMTP.default_ssl_context
        context.verify_mode = openssl_verify_mode
        context.ca_path = settings[:ca_path] if settings[:ca_path]
        context.ca_file = settings[:ca_file] if settings[:ca_file]
        context
      end
    end
  end
end
