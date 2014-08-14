# encoding: utf-8
require 'uri'
require 'json'

module Backup
  module Notifier
    class Slack < Base

      ##
      # The Team name
      attr_accessor :team

      ##
      # The Integration Token
      attr_accessor :token

      ##
      # The channel to send messages to
      attr_accessor :channel

      ##
      # The username to display along with the notification
      attr_accessor :username

      ##
      # The emoji icon to display along with the notification
      #
      # See http://www.emoji-cheat-sheet.com for a list of icons.
      #
      # Default: :floppy_disk:
      attr_accessor :icon_emoji

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
        @icon_emoji  ||= ':floppy_disk:'
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
        tag = case status
              when :success then '[Backup::Success]'
              when :failure then '[Backup::Failure]'
              when :warning then '[Backup::Warning]'
              end
        message = "#{ tag } #{ model.label } (#{ model.trigger })"

        data = { :text => message }
        [:channel, :username, :icon_emoji].each do |param|
          val = send(param)
          data.merge!(param => val) if val
        end

        data.merge!(:attachments => [attachment(status)])

        options = {
          :headers  => { 'Content-Type' => 'application/x-www-form-urlencoded' },
          :body     => URI.encode_www_form(:payload => JSON.dump(data))
        }
        options.merge!(:expects => 200) # raise error if unsuccessful
        Excon.post(uri, options)
      end

      def attachment(status)
        {
          :fallback => "#{title(status)} - Job: #{model.label} (#{model.trigger})",
          :text     => title(status),
          :color    => color(status),
          :fields   => [
            {
              :title => "Job",
              :value => "#{model.label} (#{model.trigger})",
              :short => false
            },
            {
              :title => "Started",
              :value => model.started_at,
              :short => true
            },
            {
              :title => "Finished",
              :value => model.finished_at,
              :short => true
            },
            {
              :title => "Duration",
              :value => model.duration,
              :short => true
            },
            {
              :title => "Version",
              :value => "Backup v#{Backup::VERSION}\nRuby: #{RUBY_DESCRIPTION}",
              :short => false
            },
            log_field(status)
          ].compact
        }
      end

      def log_field(status)
        send_log = send_log_on.include?(status)

        return {
          :title => "Detailed Backup Log",
          :value => Logger.messages.map(&:formatted_lines).flatten.join("\n"),
          :short => false,
        } if send_log
      end

      def color(status)
        case status
        when :success then 'good'
        when :failure then 'danger'
        when :warning then 'warning'
        end
      end

      def title(status)
        case status
        when :success then 'Backup Completed Successfully!'
        when :failure then 'Backup Failed!'
        when :warning then 'Backup Completed Successfully (with Warnings)!'
        end
      end

      def uri
        @uri ||= "https://#{team}.slack.com/services/hooks/incoming-webhook?token=#{token}"
      end
    end
  end
end
