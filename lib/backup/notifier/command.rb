# encoding: utf-8

module Backup
  module Notifier
    class Command < Base

      ##
      # Command to execute.
      #
      # Make sure it is accessible from your $PATH, or provide
      # the absolute path to the command.
      attr_accessor :command

      ##
      # Arguments to pass to the command.
      #
      # Must be an array of strings or callable objects.
      #
      # Callables will be invoked with #call(model, status),
      # and the return value used as the argument.
      #
      # In strings you can use the following placeholders:
      #
      # %l - Model label
      # %t - Model trigger
      # %s - Status (success/failure/warning)
      # %v - Status verb (succeeded/failed/succeeded with warnings)
      #
      # All placeholders can be used with uppercase letters to capitalize
      # the value.
      #
      # Defaults to ["%L %v"]
      attr_accessor :args

      def initialize(model, &block)
        super
        instance_eval(&block) if block_given?

        @args ||= ["%L %v"]
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
        IO.popen([@command] + args.map { |arg| format_arg(arg, status) })
      end

      def format_arg(arg, status)
        if arg.respond_to?(:call)
          arg.call(model, status)
        else
          arg.gsub(/%(\w)/) do |match|
            ph = match[1]
            val = case ph.downcase
                  when "l"
                    model.label
                  when "t"
                    model.trigger.to_s
                  when "v"
                    status_verb(status)
                  when "s"
                    status.to_s
                  end
            val.capitalize! if ph == ph.upcase
            val
          end
        end
      end

      def status_verb(status)
        case status
        when :success
          "succeeded"
        when :failure
          "failed"
        when :warning
          "succeeded with warnings"
        end
      end
    end
  end
end
