# encoding: utf-8
require 'aws/ses'

module Backup
  module Notifier
    class Ses < Base

      ##
      # Amazon Simple Email Service (SES) Credentials
      attr_accessor :access_key_id, :secret_access_key

      ##
      # SES Region
      attr_accessor :region

      ##
      # Sender Email Address
      attr_accessor :from

      ##
      # Receiver Email Address
      attr_accessor :to

      def initialize(model, &block)
        super
        instance_eval(&block) if block_given?

        @region ||= 'eu-west-1'
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
        AWS::SES::Base.new(
          :access_key_id => access_key_id,
          :secret_access_key => secret_access_key,
          :server => "email.#{region}.amazonaws.com"
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
        email = ::Mail.new(:to => to, :from => from)
        email.subject = message.call(model, :status => status_data_for(status))

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

        client.send_raw_email(email)
      end
    end
  end
end
