# encoding: utf-8
require 'pagerduty'

module Backup
  module Notifier
    class PagerDuty < Base

      ##
      # PagerDuty Service API Key. Should be a 32 character hex string.
      attr_accessor :service_key

      ##
      # Determines if a backup with a warning should resolve an incident rather
      # than trigger one.
      #
      # Defaults to false.
      attr_accessor :resolve_on_warning

      def initialize(mode, &block)
        super
        instance_eval(&block) if block_given?

        @resolve_on_warning ||= false
      end

      private

      ##
      # Trigger or resolve a PagerDuty incident for this model
      #
      # `status` indicates one of the following:
      #
      # `:success`
      # : The backup completed successfully.
      # : The incident will be resolved if `on_success` is `true`.
      #
      # `:warning`
      # : The backup completed successfully, but warnings were logged.
      # : An incident will be triggered if `on_warning` or `on_success` is `true`.
      #
      # `:failure`
      # : The backup operation failed.
      # : An incident will be triggered if `on_failure` is `true`.
      #
      def notify!(status)
        incident_description = "Backup - #{model.label}"
        incident_key = "backup/#{model.trigger}"
        incident_details = {
          :incident_key => incident_key,
          :details => {
            :trigger => model.trigger,
            :label => model.label,
            :started_at => model.started_at,
            :finished_at => model.finished_at,
            :duration => model.duration,
            :status => status,
            :exception => model.exception
          }
        }

        event_type = case status
                     when :success then :resolve
                     when :warning then resolve_on_warning ? :resolve : :trigger
                     when :failure then :trigger
                     end

        case event_type
        when :trigger
          pagerduty.trigger(incident_description, incident_details)
        when :resolve
          incident = pagerduty.get_incident(incident_key)
          incident.resolve(incident_description, incident_details)
        end
      end

      def pagerduty
        @pagerduty ||= Pagerduty.new(service_key)
      end
    end
  end
end
