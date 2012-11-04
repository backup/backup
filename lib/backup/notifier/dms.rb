# encoding: utf-8

module Backup
  module Notifier
    class DMS < Base

      ##
      # Snitch URL
      # The URL Dead Man's Snitch gives you when you create a new snitch
      attr_accessor :snitch_url

      def initialize(model, &block)
        super(model)

        instance_eval(&block) if block_given?

        @on_success = true
        @on_warning = true
        @on_failure = false # we want DMS to work
      end

      private

      def notify!(status)
        `#{cmd}`
      end

      def cmd
        "curl -d 'm=#{message}' #{snitch_url}"
      end

      def message
        @model.send(:elapsed_time)
      end
    end
  end
end
