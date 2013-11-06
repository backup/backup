# encoding: utf-8

module Backup
  module Notifier
    class Zabbix < Base

      attr_accessor :zabbix_host

      attr_accessor :zabbix_port

      attr_accessor :service_name

      attr_accessor :service_host

      attr_accessor :item_key

      def initialize(model, &block)
        super
        instance_eval(&block) if block_given?

        @zabbix_host  ||= Config.hostname
        @zabbix_port  ||= 10051
        @service_name ||= "Backup #{ model.trigger }"
        @service_host ||= Config.hostname
        @item_key     ||= 'backup_status'
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
        message = case status
              when :success then 'Completed Successfully'
              when :warning then 'Completed Successfully (with Warnings)'
              when :failure then 'Failed'
              end
        send_message("#{ message } in #{ model.duration }")
      end

      def send_message(message)
        msg = [service_host, service_name, model.exit_status, message].join("\t")
        cmd = "#{ utility(:zabbix_sender) }" +
              " -z '#{ zabbix_host }'" +
              " -p '#{ zabbix_port }'" +
              " -s #{ service_host }"  +
              " -k #{ item_key }"      +
              " -o '#{ msg }'"
        run("echo '#{ msg }' | #{ cmd }")
      end
    end
  end
end
