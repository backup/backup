# encoding: utf-8

module Backup
  module Notifier
    class Nagios < Base

      ##
      # Host of Nagios server to notify on backup completion.
      attr_accessor :nagios_host

      ##
      # Port of Nagios server to notify on backup completion.
      attr_accessor :nagios_port

      ##
      # Nagios nrpe configuration file.
      attr_accessor :send_nsca_cfg

      ##
      # Name of the Nagios service for the backup check.
      attr_accessor :service_name

      ##
      # Host name in Nagios for the backup check.
      attr_accessor :service_host

      def initialize(model, &block)
        super
        instance_eval(&block) if block_given?

        @nagios_host  ||= Config.hostname
        @nagios_port  ||= 5667
        @send_nsca_cfg||= "/etc/nagios/send_nsca.cfg"
        @service_name ||= "Backup #{ model.trigger }"
        @service_host ||= Config.hostname
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
        send_message(message.call(model, :status => status_data_for(status)))
      end

      def send_message(message)
        cmd = "#{ utility(:send_nsca) } -H '#{ nagios_host }' -p '#{ nagios_port }' -c '#{ send_nsca_cfg }'"
        msg = [service_host, service_name, model.exit_status, message].join("\t")
        run("echo '#{ msg }' | #{ cmd }")
      end

    end
  end
end
