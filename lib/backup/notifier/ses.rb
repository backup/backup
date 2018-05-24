require "aws-sdk"
require "mail"

module Backup
  module Notifier
    class Ses < Base
      ##
      # Amazon Simple Email Service (SES) Credentials
      attr_accessor :access_key_id, :secret_access_key, :use_iam_profile

      ##
      # SES Region
      attr_accessor :region

      ##
      # Sender Email Address
      attr_accessor :from

      ##
      # Receiver Email Address
      attr_accessor :to

      ##
      # CC receiver Email Address
      attr_accessor :cc

      ##
      # BCC receiver Email Address
      attr_accessor :bcc

      ##
      # Set reply to email address
      attr_accessor :reply_to

      def initialize(model, &block)
        super
        instance_eval(&block) if block_given?

        @region ||= "eu-west-1"
        @send_log_on ||= [:warning, :failure]
      end

      ##
      # Array of statuses for which the log file should be attached.
      #
      # Available statuses are: `:success`, `:warning` and `:failure`.
      # Default: [:warning, :failure]
      attr_accessor :send_log_on

      private

      def client
        credentials = if use_iam_profile
                        Aws::InstanceProfileCredentials.new
                      else
                        Aws::Credentials.new(access_key_id, secret_access_key)
                      end

        Aws::SES::Client.new(
          region: region,
          credentials: credentials
        )
      end

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
        email = ::Mail.new
        email.to       = to
        email.from     = from
        email.cc       = cc
        email.bcc      = bcc
        email.reply_to = reply_to
        email.subject  = message.call(model, status: status_data_for(status))

        # By default, the `mail` gem doesn't include BCC in raw output, which is
        # needed for SES to send to those addresses.
        email[:bcc].include_in_headers = true

        send_log = send_log_on.include?(status)
        template = Backup::Template.new(model: model, send_log: send_log)
        email.body = template.result(sprintf("notifier/mail/%s.erb", status.to_s))

        if send_log
          email.convert_to_multipart
          email.attachments["#{model.time}.#{model.trigger}.log"] = {
            mime_type: "text/plain;",
            content: Logger.messages.map(&:formatted_lines).flatten.join("\n")
          }
        end

        send_opts = {
          raw_message: {
            data: email.to_s
          }
        }

        if email.respond_to?(:destinations)
          send_opts[:destinations] = email.destinations
        end

        client.send_raw_email(send_opts)
      end
    end
  end
end
