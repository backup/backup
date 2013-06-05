# encoding: utf-8

module Backup
  module Notifier
    class Nagios < Base
      include Backup::Utilities::Helpers

      DEFAULT_NAGIOS_PORT = 5667

      ##
      # Host of Nagios server to notify on backup completion.
      attr_accessor :nagios_host

      ##
      # Port of Nagios server to notify on backup completion.
      attr_accessor :nagios_port

      ##
      # Name of the Nagios service for the backup check.
      attr_accessor :service_name

      ##
      # Host name in Nagios for the backup check.
      attr_accessor :service_host

      def initialize(model, &block)
        @nagios_host  = 'localhost'
        @nagios_port  = DEFAULT_NAGIOS_PORT
        @service_name = 'Backup'
        @service_host = run(utility(:hostname)).chomp

        super(model)
        instance_eval(&block) if block_given?
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
        message = case status
               when :success then 'Backup completed'
               when :warning then 'Backup completed with warnings'
               when :failure then 'Backup failed'
               end
        message += ", elapsed time: #{@model.elapsed_time}"
        send_service_check(status, message)
      end

      def service_check_data(status, message)
        code = case status
               when :success then 0
               when :warning then 1
               when :failure then 2
               end
        [service_host, service_name, code, message].join("\t")
      end

      def send_service_check(status, message)
        send_nsca_cmd = "#{utility(:send_nsca)} -H #{nagios_host}"
        send_nsca_cmd += " -p #{nagios_port}" unless nagios_port == DEFAULT_NAGIOS_PORT
        run("echo '#{service_check_data(status, message)}' | #{send_nsca_cmd}")
      end

    end
  end
end
