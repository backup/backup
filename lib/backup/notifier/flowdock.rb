# encoding: utf-8
require 'flowdock'

module Backup
  module Notifier
    class FlowDock < Base

      ##
      # The Flowdock API token
      attr_accessor :token

      ##
      # Who the notification should appear from
      attr_accessor :from_name

      # Which email the notification should appear from
      attr_accessor :from_email

      ##
      # source for message
      attr_accessor :source

      ##
      # Subject for message
      attr_accessor :subject

      ##
      # tag message in inbox
      attr_accessor :tags

      ##
      # link for message
      attr_accessor :link

      def initialize(model, &block)
        super
        instance_eval(&block) if block_given?

        @subject        ||= default_subject
        @source         ||= default_source
        @tags           ||= []
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
      # : Notification will be sent if `on_warning` or `on_success` is `true`.
      #
      # `:failure`
      # : The backup operation failed.
      # : Notification will be sent if `on_warning` or `on_success` is `true`.
      #
      def notify!(status)
        @tags  += default_tags(status)
        message = "#{ model.label } (#{ model.trigger })"
        send_message(message)
      end

      # Flowdock::Client will raise an error if unsuccessful.
      def send_message(msg)
        client = Flowdock::Flow.new(:api_token => token, :source => source,
                                    :from => {:name => from_name, :address => from_email })

        client.push_to_team_inbox(:subject => subject,
                                  :content => msg,
                                  :tags => tags,
                                  :link => link )
      end

      # set related tags
      def default_tags(status)
        case status
        when :success then ['#BackupSuccess']
        when :warning then ['#BackupWarning']
        when :failure then ['#BackupFailure']
        end
      end


      #set default source
      def default_source
        "Backup #{ model.label }"
      end

      # set default subject
      def default_subject
        'Backup Notification'
      end

    end
  end
end
